module PluginFMC

  class SettingsVM
    include ActiveModel::Validations
    include ActiveModel::Conversion
    extend ActiveModel::Naming

    attr_accessor :owner, :account, :username, :password, :bamboo_company, :bamboo_key

    def initialize(a = {})
      @owner           = a[:owner]
      @account         = a[:account]
      @username        = a[:username]
      @password        = a[:password]
      @bamboohr_key    = a[:bamboo_company]
      @bamboohr_key    = a[:bamboo_key]
    end

    def persisted?
      false
    end
  end
end