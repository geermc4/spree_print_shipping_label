class AddTaxNoteToUser < ActiveRecord::Migration
  def up
    add_column :spree_users, :tax_note, :string, :default => nil
  end

  def down
    remove_column :spree_users, :tax_note
  end
end
