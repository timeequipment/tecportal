module PluginSnohomish

  class Settings
    include ActiveModel::Serializers::JSON
    include ActiveModel::Validations
    include ActiveModel::Conversion
    extend  ActiveModel::Naming

    attr_accessor :account, :username, :password, :reasoncode, :testempid, 
      :begindate, :enddate, :justdeleteedits

    def initialize(a = {})
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