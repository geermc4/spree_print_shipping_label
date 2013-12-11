Spree::ShippingRate.class_eval do
  def shipping_label and_update_tracking = true
    label_engine = if shipping_method.name.include?('USPS')
      Spree::ShippingLabel::Endicia.new self.shipment
    elsif shipping_method.name.include?('FedEx')
      Spree::ShippingLabel::Fedex.new self.shipment
    end 
    label_engine.request_label and_update_tracking
  end
end
