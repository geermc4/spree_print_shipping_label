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

  s.files     = `git ls-files`.split($/)
  s.require_paths = ["lib"]

  s.test_files = Dir["test/**/*"]

  s.add_dependency "curb", "~> 0.8.3"
  s.add_dependency "nokogiri", "~> 1.5.9"
#  s.add_dependency "spree_active_shipping", "~> 1.2.0"
#  s.add_dependency "fedex", "~> 3.0.0"
end
