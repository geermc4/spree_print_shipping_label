class Spree::PrintShippingLabelConfiguration < Spree::Preferences::Configuration
  preference :pdfcrop, :string, :default => `which pdfcrop`.chomp

  preference :origin_telephone, :string, :default => "555-555-5555"
  preference :origin_name, :string, :default => "Some Dude"
  preference :origin_company, :string, :default => "ACME"
  preference :origin_address, :string, :default => "123 Some St"

  preference :endicia_requester_id, :string, :default => "123456"
  preference :endicia_account_id, :string, :default => "123"
  preference :endicia_password, :string, :default => "234"
  preference :endicia_url, :string, :default => "asdf"
end
