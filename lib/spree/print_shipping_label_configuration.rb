class Spree::PrintShippingLabelConfiguration < Spree::Preferences::Configuration
  preference :pdfcrop, :string, :default => `which pdfcrop`.chomp
  preference :ghost_script, :string, :default => `which gs`.chomp

  preference :origin_telephone, :string, :default => "555-555-5555"
  preference :origin_name, :string, :default => "Some Dude"
  preference :origin_company, :string, :default => "ACME"
  preference :origin_address, :string, :default => "123 Some St"

  preference :endicia_requester_id, :string, :default => "123456"
  preference :endicia_account_id, :string, :default => "123"
  preference :endicia_password, :string, :default => "234"
  preference :endicia_url, :string, :default => "asdf"

  preference :label_size, :string, :default => "4x6"
  preference :image_format, :string, :default => "PDF"
  preference :stealth_shipment, :string, :default => 'FALSE'
  preference :instured_mail, :string, :default => 'OFF'
  preference :signature_confirmation, :string, :default => 'OFF'
  preference :senders_ref, :string, :default => ''
  preference :importers_ref, :string, :default => ''
  preference :license_number, :string, :default => ''
  preference :certificate_number, :string, :default => ''
  preference :default_path, :string, :default => "public/shipments/"

  preference :requires_export_license, :boolean, :default => false
  preference :enable_eei_shipments, :boolean, :default => true
  preference :tin_type_for_eei, :string, :default => "BUSINESS_NATIONAL" # Sample default value
  preference :tin_number_for_eei, :string, :default => "12345678912" # Sample TIN
end
