Spree::Admin::OrdersController.class_eval do
  def label
    begin

      label = Spree::ShippingLabel.new params[:shipment_id]
    rescue Exception => e
      #500 doesn't really help, i want error messages on admin :D
      render :text => "#{e.message}"
    end

    send_file "public/shipments/#{label.instance_variable_get("@file")}", :disposition => 'inline', :type => 'application/pdf' unless label.blank?
  end
end
