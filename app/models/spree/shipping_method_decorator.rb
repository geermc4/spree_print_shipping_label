Spree::ShippingMethod.class_eval do
#active_shipping has this info, need to remove, some day...
  attr_accessible :api_name
  validates_presence_of :api_name
end
