# SpreePrintShippingLabel

Add print shipping label to order, currently only supports FedEx and USPS (through Endicia.com)

## Installation

Gemfile...

  gem 'fedex', :git => 'git@github.com:geermc4/fedex.git'
  gem 'spree_active_shipping', :git => "git@github.com:spree/spree_active_shipping.git"
  gem 'spree_print_shipping_label', :git => 'git@github.com:geermc4/spree_print_shipping_label.git'

Fedex cant be listed as a dependency at the moment since the published gem depends on another version of httparty
At the time, the published version of spree_active_shipping depends on other versions of spree

Copy migrations

   rake railties:install:migrations
   rake db:migrate

Make sure to add the name of the API to the shipping method



