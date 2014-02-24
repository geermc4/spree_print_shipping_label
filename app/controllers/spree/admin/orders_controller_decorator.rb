Spree::Admin::OrdersController.class_eval do
  def label
    shipment = Spree::Shipment.find_by_number(params[:shipment_id])
    declared_weight = params[:declared_weight]
    begin
      # this also updates the tracking by default
      declared_weight = declared_weight.to_f if declared_weight.present? # leave nil if it's not defined
      send_file shipment.selected_shipping_rate.shipping_label(true, declared_weight), :disposition => 'inline', :type => Mime::PDF
    rescue Spree::LabelError => exception
      flash[:error] = exception.message
      redirect_to edit_admin_order_path(shipment.order)
    end
  end
end
