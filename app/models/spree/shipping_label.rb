class Spree::ShippingLabel
  include ActiveModel::Validations
  attr_accessor :shipment, :order, :user, :shipping_address, :stock_location, :tracking, :label_response, :file_path
  validate :can_items_be_shipped?, strict: true

  def initialize shipment
    self.shipment = shipment
    self.order = self.shipment.order
    self.stock_location = self.shipment.stock_location
    self.user = self.order.user unless self.order.user.nil?
    self.shipping_address = self.order.shipping_address
    @path = Spree::PrintShippingLabel::Config[:default_path]
    @unit = Spree::ActiveShipping::Config[:units]
  end

  def request_label update_tracking = true
    raise NotImplementedError 'Subclass should implement this'
  end

  private
  def can_items_be_shipped?
    zero_weight_items = get_zero_weight_items
    zero_value_items = get_zero_value_items
    errors.add(:base, "Products need to have a weight #{prettify_item_names(zero_weight_items)}") if zero_weight_items.any?
    errors.add(:base, "Products need to have a value #{prettify_item_names(zero_value_items)}") if zero_value_items.any?
  end

  def prettify_item_names items
    items.collect(&:variant).collect(&:name).join(", ")
  end

  def get_zero_weight_items
    self.shipment.line_items.select{|i| i.variant.weight.nil? || i.variant.weight.zero?}
  end

  def get_zero_value_items
    self.shipment.line_items.select{|i| get_valid_item_price_from_line_item(i).zero?}
  end

  def shipment_weight
    self.shipment.line_items.collect(&:variant).collect(&:weight).compact.sum
  end
  def shipment_weight_in_oz
    shipment_weight * Spree::ActiveShipping::Config[:unit_multiplier]
  end

  def international?
   self.shipping_address.country.iso != "US"
  end

  def clean_phone_number number
    number.gsub(/\+|\.|\-|\(|\)|\s/, '')
  end

  def get_file_name_for_label
    "#{self.order.number}_#{self.shipment.number}"
  end

  def get_valid_item_price_from_line_item line_item
    return line_item.amount if line_item.amount > 0
    line_item.variant.price
  end

  def get_state_from_address address
    address.state ? address.state.abbr : address.state_name
  end

  def get_user_id_for_reference
    (self.user.nil? ? rand(10000) : self.user.id)
  end

  def get_full_shipping_address
    "#{self.shipping_address.address1} #{self.shipping_address.address2}" 
  end

  def write_and_crop_label_file label, file_name, margins = [0, 0, 0, 0]
    write_label_file label, file_name
    pdf_crop file_name, margins
  end

  def write_label_file label, file_name
    File.open(file_name, 'wb') { |f| f.write Base64.decode64(label) }
  end

  def pdf_crop file_name, margins = [0, 0, 0, 0]
    return unless File.exists?(Spree::PrintShippingLabel::Config[:pdfcrop])
    tmp_name = "#{(0...10).map{ ('a'..'z').to_a[rand(26)] }.join}.pdf"
    `#{Spree::PrintShippingLabel::Config[:pdfcrop]} --margins="#{margins.join(" ")}" #{file_name} #{@path}#{tmp_name} && rm #{file_name} && mv #{@path}#{tmp_name} #{file_name}`
  end

  def update_tracking_number tracking_number
    self.tracking = tracking_number
    self.shipment.update_attributes(:tracking => self.tracking)
  end
end
