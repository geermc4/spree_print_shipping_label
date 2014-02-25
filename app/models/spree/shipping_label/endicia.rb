module Spree
  class ShippingLabel::Endicia < Spree::ShippingLabel
    def request_label update_tracking = true
      label_details = parse_label_response(commit(build_body_node))
      spit_file(label_details) unless self.tracking.present? #returns single file path
      update_tracking_number( label_details[:tracking_number] ) if update_tracking
      self.file_path # return the valid file name
    end

    private

    def build_body_node
      XmlNode.new('LabelRequest', :Test => is_this_a_test?, :LabelType => get_endicia_label_type, :LabelSubtype => get_endicia_label_subtype, :LabelSize => Spree::PrintShippingLabel::Config[:label_size], :ImageFormat => Spree::PrintShippingLabel::Config[:image_format]) do |label_request|
        label_request << XmlNode.new('LabelSize', Spree::PrintShippingLabel::Config[:label_size])
        label_request << XmlNode.new('ImageFormat', Spree::PrintShippingLabel::Config[:image_format])
        label_request << XmlNode.new('Test', is_this_a_test?)

        label_request << build_form_type_node if international?

        label_request << build_mailpiece_shape if first_class_international?

        label_request << XmlNode.new('RequesterID', Spree::PrintShippingLabel::Config[:endicia_requester_id])
        label_request << XmlNode.new('AccountID', Spree::PrintShippingLabel::Config[:endicia_account_id])
        label_request << XmlNode.new('PassPhrase', Spree::PrintShippingLabel::Config[:endicia_password])
        label_request << XmlNode.new('MailClass', self.shipment.shipping_method.api_name)
        label_request << XmlNode.new('DateAdvance', 0)
        # Endicia (USPS) requires Weight to be sent in Oz
        label_request << XmlNode.new('WeightOz', shipment_weight_in_oz.round(1)) # only 1 digit after dot
        label_request << XmlNode.new('Stealth', Spree::PrintShippingLabel::Config[:stealth_shipment])
        label_request << XmlNode.new('Services', :InsuredMail => Spree::PrintShippingLabel::Config[:instured_mail], :SignatureConfirmation => Spree::PrintShippingLabel::Config[:signature_confirmation])
        label_request << XmlNode.new('Value', self.shipment.item_cost.to_f)
        label_request << XmlNode.new('Description', "##{self.order.number} / Shipment #{self.shipment.number}")
        label_request << XmlNode.new('PartnerCustomerID', get_user_id_for_reference)
        label_request << XmlNode.new('PartnerTransactionID', self.shipment.id)
        label_request << XmlNode.new('ToName', "#{self.shipping_address.firstname} #{self.shipping_address.lastname}")
        label_request << XmlNode.new('ToAddress1', self.shipping_address.address1)
        label_request << XmlNode.new('ToAddress2', self.shipping_address.address2)
        label_request << XmlNode.new('ToCity', self.shipping_address.city)
        label_request << XmlNode.new('ToState', get_state_from_address(self.shipping_address) )
        label_request << XmlNode.new('ToCountry', self.shipping_address.country.iso_name)
        label_request << XmlNode.new('ToCountryCode', self.shipping_address.country.iso)
        label_request << XmlNode.new('ToPostalCode', self.shipping_address.zipcode.gsub(/\-|\s/, ''))
        label_request << XmlNode.new('ToPhone', clean_phone_number(self.shipping_address.phone == "(not given)" ? self.order.bill_address.phone : self.shipping_address.phone))
        label_request << XmlNode.new('FromName', Spree::PrintShippingLabel::Config[:origin_name])
        label_request << XmlNode.new('FromCompany', Spree::PrintShippingLabel::Config[:origin_company])
        label_request << XmlNode.new('ReturnAddress1', Spree::PrintShippingLabel::Config[:origin_address])
        label_request << XmlNode.new('FromCity', self.stock_location.city)
        label_request << XmlNode.new('FromState', get_state_from_address(self.stock_location))
        label_request << XmlNode.new('FromPostalCode', self.stock_location.zipcode)
        label_request << XmlNode.new('FromPhone', Spree::PrintShippingLabel::Config[:origin_telephone])

        # for international shipments
        label_request << build_international_node if international?
      end
    end

    def build_international_node
      hs_tariff = "854290"
      XmlNode.new('CustomsInfo') do |customs_info|
        customs_info << XmlNode.new('ContentsType', 'Merchandise')
        customs_info << XmlNode.new('RestrictionType', 'NONE')
        customs_info << XmlNode.new('SendersCustomsReference', Spree::PrintShippingLabel::Config[:senders_ref])
        customs_info << XmlNode.new('ImportersCustomsReference', Spree::PrintShippingLabel::Config[:importers_ref])
        customs_info << XmlNode.new('LicenseNumber', Spree::PrintShippingLabel::Config[:license_number])
        customs_info << XmlNode.new('CertificateNumber', Spree::PrintShippingLabel::Config[:certificate_number])
        customs_info << XmlNode.new('InvoiceNumber', self.order.number)
        customs_info << XmlNode.new('NonDeliveryOption', 'RETURN')
        customs_info << XmlNode.new('EelPfc', '')
        customs_info << XmlNode.new('CustomsItems') do |customs_items|
          @shipment.line_items.each do |l|
            # get the product weight if defined else default to the lowest possible value
            weight = l.variant.weight.try(:to_f)
            # convert to units and round the weight because api only takes 2 digits
            weight = (weight * Spree::ActiveShipping::Config[:unit_multiplier]).round(2)
            # make sure we weight is never 0
            # this is sometimes the case when the product weight is
            # really small and rounding it to 2 digits makes it zero
            weight = (weight.zero?) ? 0.01 : weight
            # round the price value to fit API requirements
            value = get_valid_item_price_from_line_item(l).round(2)
            # check if it has price if not then its not a product that can be shipped
            # its a config part and its already defined inside another product
            # or someone forgot to define a price
            if value > 0
              customs_items << XmlNode.new('CustomsItem') do |custom_item|
                # Description has a limit of 50 characters
                custom_item << XmlNode.new('Description', l.product.name.slice(0..49))
                custom_item << XmlNode.new('Quantity', l.quantity)
                # Weight can't be 0, and its measured in oz
                custom_item << XmlNode.new('Weight', weight)
                custom_item << XmlNode.new('Value', value)
                custom_item << XmlNode.new('HSTariffNumber', hs_tariff)
                custom_item << XmlNode.new('CountryOfOrigin', 'US')
              end
            end
          end
        end
      end
    end

    def build_form_type_node
      # Form 2976 (short form: use this form if the number of items is 5 or fewer.)
      # Form 2976-A (long form: use this form if number of items is greater than 5.)
      # Required when the label subtype is Integrated.
      # Page 41

      # Values
        #Form2976
          #MaxItems: 5
          #FirstClassMailInternational
          #FirstClassPackageInternationalService
          #PriorityMailInternational (when used with FlatRateEnvelope, FlatRateLegalEnvelope, FlatRatePaddedEnvelope or SmallFlatRateBox)
        #Form2976A
          #Max Items: 999
          #PriorityMailInternational (when used with Parcel, MediumFlatRateBox or LargeFlatRateBox);
          #ExpressMailInternational (when used with FlatRateEnvelope, FlatRateLegalEnvelope or Parcel)
      # Page 151
      # Since we only use Parcel we will always choose Form2976A
      return XmlNode.new('IntegratedFormType', 'FORM2976') if first_class_international?

      XmlNode.new('IntegratedFormType', 'FORM2976A')
    end

    def build_mailpiece_shape
      XmlNode.new('MailpieceShape', 'Parcel')
    end

    def parse_label_response raw_response
      response = Nokogiri::XML::Document.parse(raw_response)
      errors = response.search('ErrorMessage')
      #validate errors
      raise Spree::LabelError.new("#{I18n.t(:label_response_error)}: USPS - #{errors.children.first.content}") if errors.present?

      # get label images and parts
      if international?
        label_images = response.search('Image').collect{ |i| {:part => i.attr('PartNumber'), :image => i.inner_text} }
      else
        label_images = [{:part => 1, :image => response.search('Base64LabelImage').inner_text}]
      end
      {
        :tracking_number => response.search("TrackingNumber").inner_text,
        :label_images => label_images
      }
    end

    def commit body, force = false
      return self.label_response if (force == false) && self.tracking.present? # don't re commit
      curl_request = Curl::Easy.http_post(build_url, Curl::PostField.content('labelRequestXML', body.to_s), :verbose => true)
      curl_request.follow_location = true
      curl_request.ssl_verify_host = false
      self.label_response = curl_request.body_str # send raw response back in chain
      self.label_response
    end

    def build_url
      "#{Spree::PrintShippingLabel::Config[:endicia_url]}GetPostageLabelXML"
    end

    def is_this_a_test?
      (Spree::ActiveShipping::Config[:test_mode]) ? 'Yes' : 'No'
    end

    def first_class_international?
       ([self.shipment.shipping_method.api_name] & ['FirstClassMailInternational', 'FirstClassPackageInternationalService']).any?
    end

    def get_endicia_label_type
      return 'International' if international?
      'Default'
    end

    def get_endicia_label_subtype
      return 'Integrated' if international?
      'None'
    end

    def spit_file label_details
      labels          = label_details[:label_images]
      part_names      = "" # this will be populated with the name parts
      self.file_path  = "#{@path}#{get_file_name_for_label}.pdf"

      labels.each do |label|
        part_file_name = "#{@path}#{get_file_name_for_label}_#{label[:part]}.pdf"
        part_names << part_file_name + " "
        write_and_crop_label_file label[:image], part_file_name
      end

      merge_pages(part_names, labels.count)
    end

    def merge_pages part_names, parts
      return unless File.exists?(Spree::PrintShippingLabel::Config[:ghost_script])
      if parts > 1
        # merge multiple pdf parts into 1 single file
        `#{Spree::PrintShippingLabel::Config[:ghost_script]} -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=#{self.file_path} #{part_names} && rm #{part_names}`
      else
        # only rename the file to the original label file
        `mv #{part_names} #{self.file_path}`
      end
    end

    # make sure the round weight requirements for this serivce
    # don't affect the weight calculations
    def shipment_weight
      return self.declared_weight if self.declared_weight
      self.shipment.inventory_units.map do |variant|
        weight = variant.try(:weight).to_f
        (weight.zero?) ? 0.01 : weight
      end.compact.sum
    end
  end
end
