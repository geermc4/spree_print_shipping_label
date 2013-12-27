Spree::Admin::OrdersController.class_eval do
  def label
    shipment = Spree::Shipment.find_by_number(params[:shipment_id])
    label_file = ""
    begin
      label_file = shipment.selected_shipping_rate.shipping_label # this also updates the tracking by default
    rescue Spree::LabelError => e
      flash[:error] = e.message
      redirect_to :back
    end
    send_file label_file, :disposition => 'inline', :type => 'application/pdf' unless label_file.blank?
  end
end
