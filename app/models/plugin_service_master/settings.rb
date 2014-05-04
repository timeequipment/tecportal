module PluginServiceMaster

  class Settings
    include ActiveModel::Serializers::JSON
    include ActiveModel::Validations
    include ActiveModel::Conversion
    extend  ActiveModel::Naming

    attr_accessor :account, :username, :password, :teamfilter, :custfilter, :weekstart

    def initialize(args = {})
      args.keys.each { |name| instance_variable_set "@" + name.to_s, args[name] }
      @account    ||= ''
      @username   ||= ''
      @password   ||= ''
      @teamfilter ||= 1
      @custfilter ||= 1
      @weekstart  ||= Date.today.beginning_of_week
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









