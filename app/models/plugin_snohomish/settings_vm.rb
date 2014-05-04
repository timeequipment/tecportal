module PluginSnohomish

  class SettingsVM
    include ActiveModel::Validations
    include ActiveModel::Conversion
    extend ActiveModel::Naming

    attr_accessor :owner, :account, :username, :password, :reasoncode, 
      :testempid, :begindate, :enddate, :justdeleteedits

    def initialize(a = {})
      @owner           = a[:owner]
      @account         = a[:account]
      @username        = a[:username]
      @password        = a[:password]
      @reasoncode      = a[:reasoncode]
      @testempid       = a[:testempid]
      @begindate       = a[:begindate]
      @enddate         = a[:enddate]
      @justdeleteedits = a[:justdeleteedits]
    end

    def persisted?
      false
    end
  end
end