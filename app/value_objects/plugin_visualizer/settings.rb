module PluginVisualizer

  class Settings
    attr_accessor \
      :account, 
      :username, 
      :password

    def initialize(account, username, password)
      @account = account
      @username = username
      @password = password
    end

  end
end