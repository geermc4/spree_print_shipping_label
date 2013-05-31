Deface::Override.new(:virtual_path  => "spree/admin/orders/_shipment",
                     :name          => "add_print_label_to_order_edit",
                     :insert_after  => "code[erb-loud]:contains(\"link_to 'ship', '#'\")",
                     :partial       => "spree/admin/orders/label")
