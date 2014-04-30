module PluginBambooHr

  class Settings
    include ActiveModel::Serializers::JSON
    include ActiveModel::Validations
    include ActiveModel::Conversion
    extend  ActiveModel::Naming

    attr_accessor :account, :username, :password, :bamboo_company, :bamboo_key

    def initialize(a = {})
      @account         = a[:account]
      @username        = a[:username]
      @password        = a[:password]
      @bamboo_company  = a[:bamboo_company]
      @bamboo_key      = a[:bamboo_key]
    end

    def persisted?
      false
    end

    # For JSON Serialization
    def attributes=(hash)
      hash.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
    end
    def attributes
      instance_values
    end

  end
end