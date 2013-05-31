Deface::Override.new(
  :virtual_path  => "spree/users/show",
  :name          => "add_tax_note_to_account_show",
  :insert_bottom => "#user-info",
  :partial       => "spree/users/show_tax_note",
)

Deface::Override.new(
  :virtual_path  => "spree/shared/_user_form",
  :name          => "add_tax_note_to_account_edit",
  :insert_before => "[data-hook='signup_below_password_fields'],#signup_below_password_fields[data-hook]",
  :partial       => "spree/users/edit_tax_note",
)
