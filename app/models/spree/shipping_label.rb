class Spree::ShippingLabel
  attr_accessor :user_id,:shipment_id,:shipping_method,:tax_note,:user_email,
                :to_name,:to_company,:to_telephone,:to_address1,:to_address2,:to_city,
                :to_state,:to_zip,:to_country,:to_residential,:origin_name,:origin_company,
                :origin_telephone,:origin_address,:origin_state,:origin_city,:origin_zip,:origin_country

  def initialize shipment
    @shipment = Spree::Shipment.find_by_number(shipment)
    @stock_location = @shipment.stock_location
    @order = @shipment.order
    @unit = Spree::ActiveShipping::Config[:units]
    if @order.user.blank?
      self.user_id = rand(10000)
      self.tax_note = ""
      self.user_email = ""
    else
      self.user_id = @order.user.id
      self.tax_note = @order.user.tax_note
      self.user_email = @order.user.email
    end

    self.shipment_id = @shipment.id
    self.shipping_method = @shipment.shipping_method.api_name

    self.to_name = "#{@order.ship_address.firstname} #{@order.ship_address.lastname}"
    self.to_company = @order.ship_address.company || ""
    self.to_telephone = clean_phone_number(@order.ship_address.phone == "(not given)" ? @order.bill_address.phone : @order.ship_address.phone)
    self.to_address1 = @order.ship_address.address1
    self.to_address2 = @order.ship_address.address2 || ""
    self.to_city = @order.ship_address.city
    self.to_state = @order.ship_address.state_name || (@order.ship_address.state.nil? ? "" : @order.ship_address.state.abbr)

    self.to_zip = @order.ship_address.zipcode.gsub(/\-|\s/, '')
    self.to_country = @order.ship_address.country.iso
    self.to_residential = @order.ship_address.company.blank? ? "true" : "false"

    self.origin_name = Spree::PrintShippingLabel::Config[:origin_name]
    self.origin_company = Spree::PrintShippingLabel::Config[:origin_company]
    self.origin_telephone = clean_phone_number(Spree::PrintShippingLabel::Config[:origin_telephone])

    self.origin_address = Spree::PrintShippingLabel::Config[:origin_address]
    self.origin_country = @stock_location.country.iso
    self.origin_state = @stock_location.state.nil? ? @stock_location.state_name : @stock_location.state.name
    self.origin_city = @stock_location.city
    self.origin_zip = @stock_location.zipcode

    @path = "public/shipments/"
    @file = "#{@order.number}_#{@order.shipments.size || 1}.pdf"
    @tmp_file = "tmp_#{@file}"

    @weight = @shipment.line_items.map{|i| i.variant.weight || 0.01}.sum # Defaults to 0.01lb -> 0.16oz

    case @shipment.shipping_method.name
      when /USPS.*/i
        usps
      when /FedEx.*/i
        fedex
    end
  end

  private
  def international?
   self.to_country != "US"
  end

  def clean_phone_number number
    number.gsub(/\+|\.|\-|\(|\)|\s/, '')
  end

  def usps
    xml = []
    xml << "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    test_attributes = "Test='Yes'"
    intl_attibutes = "LabelType='International' LabelSubtype='Integrated'"
    xml << "<LabelRequest #{(Spree::ActiveShipping::Config[:test_mode]) ? test_attributes : ""} #{(!international?) ? "LabelType='Default'" : intl_attibutes} LabelSize='4x6' ImageFormat='PDF'>"
    xml << "<LabelSize>4x6</LabelSize>"
    xml << "<ImageFormat>PDF</ImageFormat>"
    xml << "<Test>N</Test>" unless Spree::ActiveShipping::Config[:test_mode]
    if international?
      # Form 2976 (short form: use this form if the number of items is 5 or fewer.)
      # Form 2976-A (long form: use this form if number of items is greater than 5.)
      # Required when the label subtype is Integrated.
      # Page 41

      # Values
        #Form2976
          #MaxItems: 5
          #FirstClassMailInternational
          #PriorityMailInternational (when used with FlatRateEnvelope, FlatRateLegalEnvelope, FlatRatePaddedEnvelope or SmallFlatRateBox)
        #Form2976A
          #Max Items: 999
          #PriorityMailInternational (when used with Parcel, MediumFlatRateBox or LargeFlatRateBox);
          #ExpressMailInternational (when used with FlatRateEnvelope, FlatRateLegalEnvelope or Parcel)
      # Page 151
      # Since we only use Parcel we will always choose Form2976A
      xml << "<IntegratedFormType>FORM2976A</IntegratedFormType>"
    end
    xml << "<RequesterID>#{Spree::PrintShippingLabel::Config[:endicia_requester_id]}</RequesterID>"
    xml << "<AccountID>#{Spree::PrintShippingLabel::Config[:endicia_account_id]}</AccountID>"
    xml << "<PassPhrase>#{Spree::PrintShippingLabel::Config[:endicia_password]}</PassPhrase>"
    xml << "<MailClass>#{self.shipping_method}</MailClass>"
    xml << "<DateAdvance>0</DateAdvance>"
    # Endicia (USPS) requires Weight to be sent in Oz
    @weight *= Spree::ActiveShipping::Config[:unit_multiplier] # make sure weight is measured in oz
    @weight = (@weight.round(1) == 0) ? 0.1 : @weight.round(1) # make sure we dont post 0.0 
    xml << "<WeightOz>#{@weight}</WeightOz>"
    xml << "<Stealth>FALSE</Stealth>"
    xml << "<Services InsuredMail='OFF' SignatureConfirmation='OFF' />"
    # has to be greater than 0
    xml << "<Value>#{@shipment.item_cost.to_f}</Value>"
    xml << "<Description>Order ##{@order.number} / Shipment #{@shipment.number}</Description>"
    xml << "<PartnerCustomerID>#{self.user_id}</PartnerCustomerID>"
    xml << "<PartnerTransactionID>#{self.shipment_id}</PartnerTransactionID>"
    xml << "<ToName>#{self.to_name}</ToName>"
    xml << "<ToAddress1>#{self.to_address1}</ToAddress1>"
    xml << "<ToAddress2>#{self.to_address2}</ToAddress2>"
    xml << "<ToCity>#{self.to_city}</ToCity>"
    xml << "<ToState>#{self.to_state}</ToState>"
    xml << "<ToCountry>#{@order.ship_address.country.iso_name}</ToCountry>"
    xml << "<ToCountryCode>#{self.to_country}</ToCountryCode>"
    xml << "<ToPostalCode>#{self.to_zip}</ToPostalCode>"
    xml << "<ToDeliveryPoint>00</ToDeliveryPoint>"
    # remove any signs from the number
    xml << "<ToPhone>#{self.to_telephone}</ToPhone>"
    xml << "<FromName>#{self.origin_name}</FromName>"
    xml << "<FromCompany>#{self.origin_company}</FromCompany>"
    xml << "<ReturnAddress1>#{self.origin_address}</ReturnAddress1>"
    xml << "<FromCity>#{self.origin_city}</FromCity>"
    xml << "<FromState>#{self.origin_state}</FromState>"
    xml << "<FromPostalCode>#{self.origin_zip}</FromPostalCode>"
    xml << "<FromPhone>#{self.origin_telephone}</FromPhone>"
    if international?
      senders_ref         = ""
      importers_ref       = ""
      license_number      = ""
      certificate_number  = ""
      hs_tariff           = "854290"
      xml << "<CustomsInfo>"
      xml << "<ContentsType>Merchandise</ContentsType>"
      #xml << "<ContentsExplanation>Merchandise</ContentsExplanation>"
      xml << "<RestrictionType>NONE</RestrictionType>"
      #xml << "<RestrictionCommments />"
      xml << "<SendersCustomsReference>#{senders_ref}</SendersCustomsReference>"
      xml << "<ImportersCustomsReference>#{importers_ref}</ImportersCustomsReference>"
      xml << "<LicenseNumber>#{license_number}</LicenseNumber>"
      xml << "<CertificateNumber>#{certificate_number}</CertificateNumber>"
      xml << "<InvoiceNumber>#{@shipment.number}</InvoiceNumber>"
      xml << "<NonDeliveryOption>RETURN</NonDeliveryOption>"
      xml << "<EelPfc></EelPfc>"
      xml << "<CustomsItems>"
      @shipment.line_items.each do |l|
        # get the product weight if defined else default to the lowest possible value
        weight = l.variant.weight.try(:to_f) || 0.01 # 0.1lb -> 0.16oz
        # convert to units and round the weight for api
        weight = (weight * Spree::ActiveShipping::Config[:unit_multiplier]).round(2)
        weight = (weight.zero?) ? 0.01 : weight # make sure we weight is never 0
        # round the price value to fit API requirements
        value = l.amount.round(2)
        # check if it has price if not then its not a product that can be shipped
        # its a config part and its already defined inside another product
        if value > 0
          xml << "<CustomsItem>"
          # Description has a limit of 50 characters
          xml << "<Description>#{l.product.name.slice(0..49)}</Description>"
          xml << "<Quantity>#{l.quantity}</Quantity>"
          # Weight can't be 0, and its measured in oz
          xml << "<Weight>#{weight}</Weight>"
          xml << "<Value>#{value}</Value>"
          xml << "<HSTariffNumber>#{hs_tariff}</HSTariffNumber>"
          xml << "<CountryOfOrigin>US</CountryOfOrigin>"
          xml << "</CustomsItem>"
        end
      end
      xml << "</CustomsItems>"
      xml << "</CustomsInfo>"
    end

    xml << "</LabelRequest>"

    url = "#{Spree::PrintShippingLabel::Config[:endicia_url]}GetPostageLabelXML"
    c = Curl::Easy.http_post(url, Curl::PostField.content('labelRequestXML', xml.join), :verbose => true)
    c.follow_location = true
    c.ssl_verify_host = false
    res = Nokogiri::XML::Document.parse(c.body_str)
    res_error = res.search('ErrorMessage')

    if res_error.present?
      raise Spree::LabelError.new("Label Error: USPS - #{res_error.children.first.content}")
    else
      if !international?
        img = res.search('Base64LabelImage')
        File.open("#{@path}#{@file}",'wb') { |f| f.write Base64.decode64(img.inner_text) }
        pdf_crop "#{@path}#{@file}"
      else
        # Merge all the pdf parts into 1 document for easier printing
        part_names = ""
        res.search('Image').each do |i|
          File.open("#{@order.number}_#{i.attr('PartNumber')}.pdf", 'wb') { |f| f.write Base64.decode64(i.inner_text) }
          # crop pages
          pdf_crop "#{@order.number}_#{i.attr('PartNumber')}.pdf"
          part_names << "#{@order.number}_#{i.attr('PartNumber')}.pdf "
        end
        # merge pages
        gs_options = "-q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite"
        `gs #{gs_options} -sOutputFile=#{@path}#{@file} #{part_names} && rm #{part_names}`
      end
      update_tracking_number res.search("TrackingNumber").inner_text
    end

    @file
  end

  def is_part_of_kit? line_item
    ( line_item.try(:parent_id).nil? ) ? false : true
  end

  def is_kit? line_item
    ( @shipment.line_items.select{|li| li[:parent_id] == line_item[:id]}.count > 0 ) ? true : false
  end

  def line_item_kit_get_weight line_item
    return false if !is_kit?(line_item)
    @shipment.line_items.select{|l| l[:parent_id] == line_item[:id]}.collect{|l| l.variant.weight.to_f * l[:quantity]}.sum
  end

  def line_item_kit_get_value line_item
    return false if !is_kit?(line_item)
    @shipment.line_items.select{|li| li[:parent_id] == line_item[:id]}.collect{|li| li[:price] * li[:quantity] }.sum + line_item[:price]
  end

  def fedex_weight_units
    return "LB" if @unit == 'imperial'
    return "KG" if @unit == 'metric'
  end

  def fedex_dimension_units
    return "IN" if @unit == 'imperial'
    return "CM" if @unit == 'metric'
  end

  def fedex
    shipper = {
      :name => '', #self.origin_name,
      :company => self.origin_company,
      :phone_number => self.origin_telephone,
      :address => self.origin_address,
      :city => self.origin_city,
      :state => self.origin_state,
      :postal_code => self.origin_zip,
      :country_code => self.origin_country
    }

    recipient = {
      :name => self.to_name,
      :company => self.to_company,
      :phone_number => self.to_telephone,
      :address => "#{self.to_address1} #{self.to_address2}",
      :city => self.to_city,
      :state => self.to_state,
      :postal_code => self.to_zip,
      :country_code => self.to_country,
      :residential => self.to_residential
    }

    packages = []
    packages << {
      # according to mireya fedex only accepts weights bigger than 1lb
      :weight => {:units => fedex_weight_units, :value => @weight.ceil},
      # per api dimensions are optional
      :dimensions => {:length => 5, :width => 5, :height => 4, :units => fedex_dimension_units },
      :customer_references => [
        {
          :type => "INVOICE_NUMBER",
          :value => "#{@shipment.number}"
        }
      ]
    }

    shipping_details = {
      :packaging_type => "YOUR_PACKAGING",
      :drop_off_type => "REGULAR_PICKUP"
    }

    fedex = get_fedex_object

    details = { :filename => "#{@path}#{@file}",
                :shipper => shipper,
                :recipient => recipient,
                :packages => packages,
                :service_type => self.shipping_method,
                :shipping_details => shipping_details,
                :label_specification => {
                  :image_type       => "PDF",
                  :label_stock_type => "PAPER_4X6"
                }
    }
    unless self.to_country == "US"
      customs_clearance = fedex_international_aditional_info
      details.merge!( :customs_clearance => customs_clearance )
    end

    begin
      label = fedex.label(details)
      update_tracking_number label.response_details[:completed_shipment_detail][:completed_package_details][:tracking_ids][:tracking_number]
      pdf_crop "#{@path}#{@file}", [1,1,1,1]
      @file
    rescue Fedex::RateError => e
      raise Spree::LabelError.new("Label Error: FedEx - #{e.message}")
    end
  end
  
  def get_fedex_object
    Fedex::Shipment.new(
      :key => Spree::ActiveShipping::Config[:fedex_key],
      :password => Spree::ActiveShipping::Config[:fedex_password],
      :account_number => Spree::ActiveShipping::Config[:fedex_account],
      :meter => Spree::ActiveShipping::Config[:fedex_login],
      :mode => ( Spree::ActiveShipping::Config[:test_mode] ? 'development' : 'production' )
    )
  end

  def fedex_international_aditional_info
    broker = {
      :contact => {
        :contact_id => self.user_id,
        :person_name => self.to_name,
        :title => "Broker",
        :company_name => self.to_company,
        :phone_number => self.to_telephone,
        :e_mail_address => self.user_email,
      },
      :address => {
        :street_lines => "#{self.to_address1} #{self.to_address2}",
        :city => self.to_city,
        :state_or_province_code => self.to_state,
        :postal_code => self.to_zip,
        :country_code => self.to_country
      }
    }

    commercial_invoice = {
      :purpose_of_shipment_description => "SOLD",
      :customer_invoice_number => @order.number,
      :originator_name => self.origin_name,
      :terms_of_sale => "EXW",
    }

    recipient_customs_id = { :type => 'INDIVIDUAL', :value => self.tax_note || "" }

    duties_payment = {
      :payment_type => "SENDER",
      :payor => {
        :account_number => Spree::ActiveShipping::Config[:fedex_account],
        :country_code => "US"
      }
    }

    commodities = @shipment.line_items.collect{ |line_item| comodity(line_item.variant, line_item.quantity, line_item.price) }
    customs_value_amount = commodities.collect{|c| c[:customs_value][:amount] }.sum
    customs_value = { :currency => "USD", :amount => customs_value_amount }

    {
      :broker => broker,
      :clearance_brokerage => "BROKER_INCLUSIVE",
      :importer_of_record => broker,
      :recipient_customs_id => recipient_customs_id,
      :duties_payment => duties_payment,
      :customs_value => customs_value,
      :commercial_invoice => commercial_invoice,
      :commodities => commodities,
    }
  end

  def comodity variant, quantity, price = -1
    price = variant.price if price == -1
    desc = ActionView::Base.full_sanitizer.sanitize("#{variant.product.name}")
    opts = ActionView::Base.full_sanitizer.sanitize("( #{ variant.options_text } )") unless variant.options_text.blank?
    desc = "#{desc} #{opts}" unless opts.blank?
    {
        :name => variant.name,
        :number_of_pieces => quantity,
        :description => "#{desc[0,447]}...", #450 Fedex API limit for the field
        :country_of_manufacture => "US",
        :weight => { :units => "LB", :value => "#{(( variant.weight.to_f || 0 ) * quantity) || '0'}"},
        :quantity => quantity,
        :quantity_units => quantity,
        :unit_price => { :currency => "USD", :amount => price.to_f},
        :customs_value => { :currency => "USD", :amount => (price * quantity).to_f}
      }
  end

  def pdf_crop file_name, margins = [0, 0, 0, 0]
    return unless File.exists?(Spree::PrintShippingLabel::Config[:pdfcrop])
    tmp_name = "#{(0...10).map{ ('a'..'z').to_a[rand(26)] }.join}.pdf"
    `#{Spree::PrintShippingLabel::Config[:pdfcrop]} --margins="#{margins.join(" ")}" #{file_name} #{@path}#{tmp_name} && rm #{file_name} && mv #{@path}#{tmp_name} #{file_name}`
  end

  def update_tracking_number t_number
    @shipment.tracking = t_number
    @shipment.save
  end
end