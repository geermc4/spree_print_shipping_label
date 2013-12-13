Spree::Core::Engine.append_routes do
#  match "/admin/orders/:order_id/label/:shipment_id", :to => "admin/orders/#label", :as => :shipping_label
  namespace :admin do
    get 'orders/:order_id/label/:shipment_id', :to => "orders#label", :as => :shipping_label
  end
end
