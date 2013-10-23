Spree::Admin::OrdersController.class_eval do
  def label
    begin
      label = Spree::ShippingLabel.new params[:shipment_id]
    rescue Spree::LabelError => e
      report_errors e
      flash[:error] = e.message
      redirect_to :back
    end

    send_file "public/shipments/#{label.instance_variable_get("@file")}", :disposition => 'inline', :type => 'application/pdf' unless label.blank?
  end

  private
  def report_errors exception
    @order = Spree::Order.find_by_number!(params[:order_id]) if params[:order_id]
    exception.set_backtrace("#{@order.number} - #{@order.email}")
    ExceptionNotifier.notify_exception(exception, :data => request.env["exception_notifier.exception_data"])
  end
end
