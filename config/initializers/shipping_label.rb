class Endicia
  class << self
    attr_accessor :requester_id
    attr_accessor :account_id
    attr_accessor :password
    attr_accessor :url
  end
end
Store::Application.configure do
  config.after_initialize do
    Endicia.requester_id = "j07rdi@gmail.com"
    Endicia.account_id = "867163"
    Endicia.password = "af-cag-yoif-net-v"
    if Rails.env == 'production'
      Endicia.url = "https://labelserver.endicia.com/LabelService/EwsLabelService.asmx/"
    else
      Endicia.url = "https://www.envmgr.com/LabelService/EwsLabelService.asmx/"
    end
  end
end
