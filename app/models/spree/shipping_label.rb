class Spree::ShippingLabel
  include ActiveModel::Validations
  attr_accessor :shipment, :order, :user, :shipping_address, :stock_location, :tracking, :label_response, :file_path, :eei_statement, :declared_weight
  validate :can_items_be_shipped?, strict: true

  EEI_EXEMPT = %w(CA AS MP GU)
  EEI_REQUIRED = %w(CU IR KP SD SY)

  def initialize shipment, declared_weight = nil, eei_statement = ""
    self.shipment = shipment
    self.order = self.shipment.order
    self.stock_location = self.shipment.stock_location
    self.user = self.order.user unless self.order.user.nil?
    self.shipping_address = self.order.shipping_address
    self.eei_statement = eei_statement
    self.declared_weight = declared_weight
    @path = Spree::PrintShippingLabel::Config[:default_path]
    @unit = Spree::ActiveShipping::Config[:units]
  end

  def request_label update_tracking = true
    raise NotImplementedError 'Subclass should implement this'
  end

  private
  def can_items_be_shipped?
    zero_weight_items = get_zero_weight_items
    #zero_value_items = get_zero_value_items
    errors.add(:base, "Products need to have a weight #{prettify_item_names(zero_weight_items)}") if zero_weight_items.any?
    #errors.add(:base, "Products need to have a value #{prettify_item_names(zero_value_items)}") if zero_value_items.any?
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

  def shipment_item_total
    self.shipment.item_cost.to_f
  end

  def shipment_weight
    return self.declared_weight if self.declared_weight
    self.shipment.inventory_units.map(&:variant).map(&:weight).compact.sum
  end

  def shipment_weight_in_oz
    shipment_weight * Spree::ActiveShipping::Config[:unit_multiplier]
  end

  def ships_from_usa?
    self.stock_location.country.iso == "US"
  end

  def international?
   self.shipping_address.country.iso != "US"
  end

  def requires_eei?
    # this is not required if you are not shipping from the US
    return false if !ships_from_usa?

    # START: EEI README (Electronic Export Information)
    #
    # The Electronic Export Information (EEI) is the equivalent electronic version of the Shipper’s Export Declaration (SED), Department of Commerce (Census Bureau) form 7525-V, which can no longer be submitted to the U.S. government (as of September 30, 2008). The EEI provides export statistics and control by reporting all pertinent export data of an international shipment transaction.
    #
    # The EEI is required by the U.S. Department of Census to obtain statistical data and also by the Bureau of Industry and Security (BIS) to assist in enforcing export controls. The EEI is required when the total value of goods classified under any Schedule B number exceeds $2500 USD or the commodities listed require an export license. This information is mandatory and must be submitted electronically by the exporter or agent through the Automated Export System (AES) for commodities listed on the Commerce Control List (CCL).
    #
    # The EEI is not required for shipments from the U.S. to Canada unless the merchandise is subject to International Traffic in Arms Regulations (ITAR) or requires an export license or permit. An EEI is not required for shipment to other U.S. possessions (American Samoa, Baker Island, Commonwealth or the Northern Mariana Islands, Guam, Howland Islands, Jarvis Island, Johnston Atoll, Kingmen Reef, Midway Islands, Navassa Island, Palmyra Atoll, and Wake Island) or from the U.S. Virgin Islands to the U.S. or Puerto Rico.
    #
    # WHEN TO FILE
    #
    # You must file an EEI for all shipments from the U.S., Puerto Rico or the U.S. Virgin Islands to foreign destinations.
    # It is also required for all shipments between the U.S. and Puerto Rico,
    # and from the U.S. or Puerto Rico to the U.S. Virgin Islands if any of the following apply:
    #
    # • Shipment of merchandise under the same Schedule B commodity number is valued at more than $2,500 USD and is sent from the same exporter to the same recipient on the same day. ```Note:``` Shipments to Canada from the U.S. are exempt from this requirement
    # • The shipment contains merchandise, regardless of value, that requires an export license or permit.
    # • The merchandise is subject to International Traffic in Arms Regulations (ITAR), regardless of value.
    # • The shipment, regardless of value, is being sent to Cuba, Iran, North Korea, Sudan or Syria.
    # • The shipment contains rough diamonds, regardless of value (HTS 7102.10, 7102.21 and 7102.31).
    #
    # END README

    # if the commerce is seling arms or diamonds and some other cases
    # then you must ALWAYS require EEI... unless you don't ship from the US
    return true if requires_export_license?
    # if you are shipping to: Cuba, Iran, North Korea, Sudan or Syria.
    return true if country_eei_required?
    # if the shipping country is on the exemption list then you don't require
    # the EEI, unless you set the above config to true
    return false if country_eei_exempt?
    # if you ship from US to a country outside the US
    # and your shipment value is bigger than $2,500 USD
    # you should fill the EEI
    return true if (shipment_item_total > 2500) && ships_from_usa? && international?

    # default to no EEI if no conditions are met
    false
  end

  def country_eei_exempt?
    # An EEI is not required for shipment to other U.S. possessions (American Samoa, Baker Island, Commonwealth or the Northern Mariana Islands, Guam, Howland Islands, Jarvis Island, Johnston Atoll, Kingmen Reef, Midway Islands, Navassa Island, Palmyra Atoll, and Wake Island)
    ([self.shipping_address.country.iso] & EEI_EXEMPT).any?
  end

  def country_eei_required?
    # The shipment, regardless of value, is being sent to Cuba, Iran, North Korea, Sudan or Syria.
    ([self.shipping_address.country.iso] & EEI_REQUIRED).any?
  end

  def requires_export_license?
    Spree::PrintShippingLabel::Config[:requires_export_license]
  end

  def eei_shipments_enabled?
    Spree::PrintShippingLabel::Config[:enable_eei_shipments]
  end

  def check_eei_restrictions_and_raise_errors
    # if the shipment requires EEI but it's been disabled on this store
    errors.add(:base, "#{I18n.t(:label_response_error)}: #{I18n.t(:eei_restrictions)}") if !(eei_shipments_enabled?)
    # if the EEI + ITN number isn't present and it's required
    errors.add(:base, "#{I18n.t(:eei_not_present)}") if self.eei_statement.present?
  end

  def clean_phone_number number
    number.gsub(/\+|\.|\-|\(|\)|\s/, '')
  end

  def get_file_name_for_label
    "#{self.order.number}_#{self.shipment.number}"
  end

  def get_valid_item_price_from_line_item line_item
    #return line_item.amount if line_item.amount > 0
    #line_item.variant.price
    line_item.amount
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
