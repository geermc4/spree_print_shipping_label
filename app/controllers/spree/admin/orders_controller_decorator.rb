Spree::Admin::OrdersController.class_eval do
  def label
    begin
      label = Spree::ShippingLabel.new params[:shipment_id]
    rescue Exception => e
      flash[:error] = e.message
      redirect_to :back
    end

    send_file "public/shipments/#{label.instance_variable_get("@file")}", :disposition => 'inline', :type => 'application/pdf' unless label.blank?
  end
end
