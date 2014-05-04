module PluginServiceMaster::ViewModels

  class SettingsVM
    include ActiveModel::Validations
    include ActiveModel::Conversion
    extend ActiveModel::Naming

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
  end
end