class Spree::ShippingLabel
  attr_accessor :user_id,:shipment_id,:shipping_method,:tax_note,:user_email,
                :to_name,:to_company,:to_telephone,:to_address1,:to_address2,:to_city,
                :to_state,:to_zip,:to_country,:to_residential,:origin_name,:origin_company,
                :origin_telephone,:origin_address,:origin_state,:origin_city,:origin_zip,:origin_country

  def initialize shipment
    @shipment = Spree::Shipment.find_by_number(shipment)
    @order = @shipment.order
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
    self.to_telephone = @order.ship_address.phone == "(not given)" ? @order.bill_address.phone : @order.ship_address.phone
    self.to_address1 = @order.ship_address.address1
    self.to_address2 = @order.ship_address.address2 || ""
    self.to_city = @order.ship_address.city
    self.to_state = @order.ship_address.state_name || @order.ship_address.state.abbr

    self.to_zip = @order.ship_address.zipcode
    self.to_country = Spree::Country.find(@order.ship_address.country_id).iso
    self.to_residential = @order.ship_address.company.blank? ? "true" : "false"

    self.origin_name = Spree::PrintShippingLabel::Config[:origin_name]
    self.origin_company = Spree::PrintShippingLabel::Config[:origin_company]
    self.origin_telephone = Spree::PrintShippingLabel::Config[:origin_telephone]
    self.origin_address = Spree::PrintShippingLabel::Config[:origin_address]
    self.origin_country = Spree::ActiveShipping::Config[:origin_country]
    self.origin_state = Spree::ActiveShipping::Config[:origin_state]
    self.origin_city = Spree::ActiveShipping::Config[:origin_city]
    self.origin_zip = Spree::ActiveShipping::Config[:origin_zip]

    @path = "public/shipments/"
    @file = "#{@order.number}_#{@order.shipments.size || 1}.pdf"
    @tmp_file = "tmp_#{@file}"

    @weight = 0
    @shipment.inventory_units.each do |i|
      @weight = @weight + i.variant.weight unless i.variant.weight.blank?
    end
    @weight = 1 if @weight < 1

    case @shipment.shipping_method.name
      when /USPS.*/i
        usps
      when /FedEx.*/i
        fedex
    end
  end

  #private
  def usps
    xml = []
    xml << "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    xml << "<LabelRequest LabelType='Default' LabelSize='4X6' ImageFormat='PDF'>"
    xml << "<Test>N</Test>" unless Spree::ActiveShipping::Config[:test_mode]
    xml << "<RequesterID>#{::Endicia.requester_id}</RequesterID>"
    xml << "<AccountID>#{Endicia.account_id}</AccountID>"
    xml << "<PassPhrase>#{Endicia.password}</PassPhrase>"
    xml << "<MailClass>#{self.shipping_method}</MailClass>"
    xml << "<DateAdvance>0</DateAdvance>"
    xml << "<WeightOz>#{@weight}</WeightOz>"
    xml << "<Stealth>FALSE</Stealth>"
    xml << "<Services InsuredMail='OFF' SignatureConfirmation='OFF' />"
    xml << "<Value>0</Value>"
    xml << "<Description>Label for order ##{@order.number}</Description>"
    xml << "<PartnerCustomerID>#{self.user_id}</PartnerCustomerID>"
    xml << "<PartnerTransactionID>#{self.shipment_id}</PartnerTransactionID>"
    xml << "<ToName>#{self.to_name}</ToName>"
    xml << "<ToAddress1>#{self.to_address1}</ToAddress1>"
    xml << "<ToCity>#{self.to_city}</ToCity>"
    xml << "<ToState>#{self.to_state}</ToState>"
    xml << "<ToPostalCode>#{self.to_zip}</ToPostalCode>"
    xml << "<ToDeliveryPoint>00</ToDeliveryPoint>"
    xml << "<ToPhone>#{self.to_telephone}</ToPhone>"
    xml << "<FromName>#{self.origin_name}</FromName>"
    xml << "<FromCompany>#{self.origin_company}</FromCompany>"
    xml << "<ReturnAddress1>#{self.origin_address}</ReturnAddress1>"
    xml << "<FromCity>#{self.origin_city}</FromCity>"
    xml << "<FromState>#{self.origin_state}</FromState>"
    xml << "<FromPostalCode>#{self.origin_zip}</FromPostalCode>"
    xml << "<FromPhone>#{self.origin_telephone}</FromPhone>"
    xml << "</LabelRequest>"

    url = "#{Endicia.url}GetPostageLabelXML"
    c = Curl::Easy.http_post(url, Curl::PostField.content('labelRequestXML', xml.join), :verbose => true)
    c.follow_location = true
    c.ssl_verify_host = false
    res = Nokogiri::XML::Document.parse(c.body_str)
    img = res.search('Base64LabelImage')
    File.open("#{@path}#{@file}",'wb') { |f| f.write Base64.decode64(img.inner_text) }

    update_tracking_number res.search("TrackingNumber").inner_text
    pdf_crop
    @file
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
      :weight => {:units => "LB", :value => @weight},
      :dimensions => {:length => 5, :width => 5, :height => 4, :units => "IN" }
    }

    shipping_details = {
      :packaging_type => "YOUR_PACKAGING",
      :drop_off_type => "REGULAR_PICKUP"
    }

    fedex = Fedex::Shipment.new(
      :key => Spree::ActiveShipping::Config[:fedex_key],
      :password => Spree::ActiveShipping::Config[:fedex_password],
      :account_number => Spree::ActiveShipping::Config[:fedex_account],
      :meter => Spree::ActiveShipping::Config[:fedex_login],
      :mode => ( Spree::ActiveShipping::Config[:test_mode] ? 'development' : 'production' )
    )

    details = { :filename => "#{@path}#{@file}",
                :shipper => shipper,
                :recipient => recipient,
                :packages => packages,
                :service_type => self.shipping_method,
                :shipping_details => shipping_details }
    unless self.to_country == "US"
      customs_clearance = fedex_international_aditional_info
      details.merge!( :customs_clearance => customs_clearance )
    end

    label = fedex.label(details)
    update_tracking_number label.response_details[:completed_shipment_detail][:completed_package_details][:tracking_ids][:tracking_number]
    pdf_crop
    @file
  end

  def fedex_international_aditional_info
    broker={
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

    importer_of_record = broker
#**************
    recipient_customs_id = { :type => 'INDIVIDUAL', :value => self.tax_note || "" }
#**************
    duties_payment = {
      :payment_type => "SENDER",
      :payor => {
        :account_number => Spree::ActiveShipping::Config[:fedex_account],
        :country_code => "US"
      }
    }

    commodities = []

    @order.line_items.each do |l|
      #next unless i.in_shipment @shipment.number
      if l.product.assembly?
        l.product.parts_with_price.each do |p|
          commodities << comodity(p[:variant], p[:count], p[:price])
        end
      else
        commodities << comodity(l.variant, l.quantity, l.price)
      end
    end

    cv = 0
    commodities.each do |c|
      cv += c[:customs_value][:amount]
    end

    customs_value = {
      :currency => "USD", :amount => cv }

    customs_clearance = {
      :broker => broker,
      :clearance_brokerage => "BROKER_INCLUSIVE",
      :importer_of_record => importer_of_record,
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
        :unit_price => { :currency => "USD", :amount => variant.price.to_f},
        :customs_value => { :currency => "USD", :amount => (variant.price * quantity).to_f}
      }
  end

  def pdf_crop
    `#{Spree::PrintShippingLabel::Config[:pdfcrop]} #{@path}#{@file} #{@path}#{@tmp_file} && rm #{@path}#{@file} && mv #{@path}#{@tmp_file} #{@path}#{@file}` unless Spree::PrintShippingLabel::Config[:pdfcrop].blank?
  end

  def update_tracking_number t_number
    @shipment.tracking = t_number
    @shipment.save
  end
end

