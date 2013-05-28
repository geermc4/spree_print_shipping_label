$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "spree_print_shipping_label/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "spree_print_shipping_label"
  s.version     = SpreePrintShippingLabel::VERSION
  s.authors     = ["German Garcia"]
  s.email       = ["geermc4@gmail.com"]
  s.homepage    = "https://github.com/geermc4/spree_print_shipping_label"
  s.summary     = "Adds a print button on a shipment to get shipping label"
  s.description = "Requires accounts for USPS (through endicia) and Fedex label services"

  gem.files         = `git ls-files`.split($/)

  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 3.2.13"
#  s.add_dependency "fedex", "~> 3.0.0"
end
