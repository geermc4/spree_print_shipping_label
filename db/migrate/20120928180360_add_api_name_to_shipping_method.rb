class AddApiNameToShippingMethod < ActiveRecord::Migration
  def up
		add_column :spree_shipping_methods, :api_name, :string, :null => false
  end

	def down
		remove_column :spree_shipping_methods, :api_name
	end
end
