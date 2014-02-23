module PluginServiceMaster

  class SettingsVM
    include ActiveModel::Validations
    include ActiveModel::Conversion
    extend ActiveModel::Naming

    attr_accessor :owner, :account, :username, :password

    def initialize(a = {})
      @owner =           a[:owner]
      @account =         a[:account]
      @username =        a[:username]
      @password =        a[:password]
    end

    def persisted?
      false
    end
  end
end