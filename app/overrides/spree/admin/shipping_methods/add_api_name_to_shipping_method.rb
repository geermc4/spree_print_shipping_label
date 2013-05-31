Deface::Override.new(:virtual_path  => "spree/admin/shipping_methods/_form",
                     :name          => "add_api_name_to_shipping_method",
                     :insert_bottom => "[data-hook='admin_shipping_method_form_fields'], #admin_shipping_method_form_fields[data-hook]",
                     :partial       => "spree/admin/shipping_methods/add_api_name_to_shipping_method")
