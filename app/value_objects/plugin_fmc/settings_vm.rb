module PluginFMC

  class SettingsVM
    include ActiveModel::Validations
    include ActiveModel::Conversion
    extend ActiveModel::Naming

    attr_accessor :owner, :account, :username, :password, :includeunmapped, :paycodemappings

    def initialize(a = {})
      @owner =           a[:owner]
      @account =         a[:account]
      @username =        a[:username]
      @password =        a[:password]
      @includeunmapped = a[:includeunmapped]
      @paycodemappings = a[:paycodemappings]
    end

    def persisted?
      false
    end
  end
end