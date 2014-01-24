require 'fedex'

module Spree
  class ShippingLabel::Fedex < Spree::ShippingLabel
    def request_label update_tracking = true
      label_details = parse_label_response(commit(build_body_node))
      self.file_path = label_details[:label_images]
      update_tracking_number( label_details[:tracking_number] ) if update_tracking
      self.file_path
    end
    private
    def build_body_node
      details = {
        :shipper => build_shipper_node,
        :recipient => build_recipient_node,
        :packages => build_shipment_details_node,
        :service_type => self.shipment.shipping_method.api_name,
        :shipping_details => {
          :packaging_type => "YOUR_PACKAGING",
          :drop_off_type => "REGULAR_PICKUP"
        },
        :label_specification => {
          :image_type       => "PDF",
          :label_stock_type => "PAPER_4X6"
        }
      }
      details.merge!(build_international_node) if international?

      details
    end

    def build_international_node
      {
        :customs_clearance_detail => {
          :brokers => build_broker_contact_node,
          :clearance_brokerage => "BROKER_INCLUSIVE",
          :importer_of_record => build_broker_node,
          :recipient_customs_id => build_recipient_customs_id_node,
          :duties_payment => {
            :payment_type => "RECIPIENT"
          },
          :customs_value => build_customs_value_node,
          :commodities => self.shipment.line_items.collect{ |line_item| comodity(line_item) }
        }
      }
    end

    def commit request
      fedex = get_fedex_object
      begin
        # note that this already saves the file to disk
        fedex.label(request)
      rescue ::Fedex::RateError => fedex_error
        raise Spree::LabelError.new("Label Response Error: FedEx - #{fedex_error.message}")
      end
    end

    def parse_label_response response
      response_details = response.response_details
      file_name = spit_file response, "#{get_file_name_for_label}.pdf" # safe the pdf to disk
      raise Spree::LabelError.new("Label Response Error: FedEx - No label file found") unless File.exists?(file_name)
      # crop file before sending and
      # chop margins for better printing
      pdf_crop file_name, [1,1,1,1]
      {
        :tracking_number => response_details[:completed_shipment_detail][:completed_package_details][:tracking_ids][:tracking_number],
        :label_images => file_name
      }
    end


    def build_shipper_node
      {
        :name => '',
        :company => Spree::PrintShippingLabel::Config[:origin_company],
        :phone_number => Spree::PrintShippingLabel::Config[:origin_telephone],
        :address => Spree::PrintShippingLabel::Config[:origin_address],
        :city => self.stock_location.city,
        :state => get_state_from_address(self.stock_location),
        :postal_code => self.stock_location.zipcode,
        :country_code => self.stock_location.country.iso
      }
    end

    def build_recipient_node
      {
        :name => "#{self.shipping_address.firstname} #{self.shipping_address.lastname}",
        :company => '',
        :phone_number => clean_phone_number(self.shipping_address.phone == '(not given)' ? self.order.bill_address.phone : self.shipping_address.phone),
        :address => get_full_shipping_address,
        :city => self.shipping_address.city,
        :state => get_state_from_address(self.shipping_address),
        :postal_code => self.shipping_address.zipcode.gsub(/\-|\s/, ''),
        :country_code => self.shipping_address.country.iso,
        :residential => self.shipping_address.company.blank? ? "true" : "false"
      }
    end

    def build_shipment_details_node
      [{
        # according to mireya fedex only accepts weights bigger than 1lb
        # fedex accepts lb don't use oz!!!
        :weight => {:units => fedex_weight_units, :value => shipment_weight},
        # per api dimensions are optional
        :dimensions => {:length => 5, :width => 5, :height => 4, :units => fedex_dimension_units },
        :customer_references => build_customer_references_node
      }]
    end

    def build_customer_references_node
      [{ :type => "INVOICE_NUMBER", :value => "#{self.order.number} - #{self.shipment.number}" }]
    end

    def build_recipient_customs_id_node
      { :type => 'INDIVIDUAL', :value => (self.user ? self.user.tax_note : "") }
    end

    def build_customs_value_node
      { :currency => "USD", :amount => self.shipment.item_cost.to_f }
    end

    def build_broker_contact_node
      {
        :Type => 'IMPORT',
        :Broker => build_broker_node
      }
    end

    def build_broker_node
      {
        :contact => {
          :contact_id => get_user_id_for_reference,
          :person_name => "#{self.shipping_address.firstname} #{self.shipping_address.lastname}",
          :title => "Broker",
          :company_name => self.shipping_address.company || "",
          :phone_number => clean_phone_number(self.shipping_address.phone == "(not given)" ? self.order.bill_address.phone : self.shipping_address.phone),
          :e_mail_address => self.order.email,
        },
        :address => {
          :street_lines => get_full_shipping_address,
          :city => self.shipping_address,
          :state_or_province_code => get_state_from_address(self.shipping_address),
          :postal_code => self.shipping_address.zipcode,
          :country_code => self.shipping_address.country.iso
        }
      }
    end

    def comodity line_item
      price = get_valid_item_price_from_line_item line_item
      desc = ActionView::Base.full_sanitizer.sanitize("#{ line_item.variant.product.name }")
      opts = ActionView::Base.full_sanitizer.sanitize("( #{ line_item.variant.options_text } )") unless line_item.variant.options_text.blank?
      desc = "#{desc} #{opts}" unless opts.blank?
      {
          :name => line_item.variant.name,
          :number_of_pieces => line_item.quantity,
          :description => "#{desc[0,447]}...", #450 Fedex API limit for the field
          :country_of_manufacture => "US",
          :weight => { :units => "LB", :value => line_item.variant.weight},
          :quantity => line_item.quantity,
          :quantity_units => line_item.quantity,
          :unit_price => { :currency => "USD", :amount => price.to_f},
          :customs_value => { :currency => "USD", :amount => (price * line_item.quantity).to_f}
        }
    end

    def get_fedex_object
      ::Fedex::Shipment.new(
        :key => Spree::ActiveShipping::Config[:fedex_key],
        :password => Spree::ActiveShipping::Config[:fedex_password],
        :account_number => Spree::ActiveShipping::Config[:fedex_account],
        :meter => Spree::ActiveShipping::Config[:fedex_login],
        :mode => ( Spree::ActiveShipping::Config[:test_mode] ? 'development' : 'production' )
      )
    end

    def fedex_weight_units
      return "LB" if @unit == 'imperial'
      return "KG" if @unit == 'metric'
    end

    def fedex_dimension_units
      return "IN" if @unit == 'imperial'
      return "CM" if @unit == 'metric'
    end

    def spit_file response, file_name
      response.save("#{@path}#{file_name}", false)
      "#{@path}#{file_name}"
    end
  end
end
