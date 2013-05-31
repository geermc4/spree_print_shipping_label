require "spree_print_shipping_label/version"

module Spree::PrintShippingLabel
end

module SpreePrintShippingLabelExtension
 class Engine < Rails::Engine
    engine_name 'spree_print_shipping_label'

    initializer "spree.print_shipping_label.preferences", :before => :load_config_initializers do |app| #, :after => 'spree.register.calculators' do |app|
      Spree::PrintShippingLabel::Config = Spree::PrintShippingLabelConfiguration.new
      Spree::PrintShippingLabel::Config[:endicia_url] = Rails.env == 'production' ? "https://labelserver.endicia.com/LabelService/EwsLabelService.asmx/" : "https://www.envmgr.com/LabelService/EwsLabelService.asmx/"
    end

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), "../app/**/*_decorator*.rb")) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
    end
    config.autoload_paths += %W(#{config.root}/lib)
    config.to_prepare &method(:activate).to_proc
  end
end
