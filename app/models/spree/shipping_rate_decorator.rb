Spree::ShippingRate.class_eval do
  def shipping_label and_update_tracking = true, declared_weight = nil
    label_engine = if shipping_method.name.include?('USPS')
      Spree::ShippingLabel::Endicia.new self.shipment, declared_weight
    elsif shipping_method.name.include?('FedEx')
      Spree::ShippingLabel::Fedex.new self.shipment, declared_weight
    end 

    label_engine.errors[:base].each do |error|
      raise Spree::LabelError.new error
    end unless label_engine.valid?

    label_engine.request_label and_update_tracking
  end
end
