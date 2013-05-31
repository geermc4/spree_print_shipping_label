=begin
Application.configure do
  initializer "spree.print_shipping_label_url", :after => 'spree.shipping_label.preferences' do |app|
    if Rails.env == 'production'
      Spree::ShippingLabelConfiguration[:endicia_url] = "https://labelserver.endicia.com/LabelService/EwsLabelService.asmx/"
    else
      Spree::ShippingLabelConfiguration[:endicia_url] = "https://www.envmgr.com/LabelService/EwsLabelService.asmx/"
    end
  end
end
=end
