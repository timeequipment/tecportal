class ApplicationController < ActionController::Base
  protect_from_forgery
  require 'awesome_print'
  require 'savon'

  $debug_msg = ''
  $debug_hash = {}

  def log key, value, indent = 4
    indent.times { print ' '}
    print '    ' + key + ': '
    ap value, :indent => 8 + indent, :color => {
      :args       => :red,   # purpleish
      :array      => :white,
      :bigdecimal => :blue,
      :class      => :yellow,
      :date       => :blueish,
      :falseclass => :red,
      :fixnum     => :blue,
      :float      => :blue,
      :hash       => :gray,  # redish
      :keyword    => :cyan,  # cyanish
      :method     => :purpleish,
      :nilclass   => :red,
      :rational   => :blue,
      :string     => :yellowish,
      :struct     => :pale,
      :symbol     => :cyanish,
      :time       => :blue,
      :trueclass  => :green,
      :variable   => :cyanish
    }
  end

  def create_conn(cls, user_id, customer_id, plugin_id)
    log 'method', 'create_conn', 0
    # Get plugin settings
    settings = get_user_settings(cls, user_id, plugin_id) 
    settings ||= get_customer_settings(cls, customer_id, plugin_id)
    settings ||= cls.new
    log 'aod account', settings.account
    log 'aod username', settings.username
    log 'aod password', settings.password

    # Return interface to AoD
    Savon.client(
      wsdl: "https://#{ settings.account }.attendanceondemand.com:8192/cc1.aew/wsdl/IAeXMLBridge", 
      endpoint: "https://#{ settings.account }.attendanceondemand.com:8192/cc1exec.aew/soap/IAeXMLBridge", 
      basic_auth: [settings.username, settings.password],
      log: true,
      log_level: :info, # change to :debug to log HTTP messages
      pretty_print_xml: true)
  end

  def get_user_settings(cls, user_id, plugin_id)
    log 'method', 'get_user_settings', 0
    s = UserSettings.where(
      user_id: user_id, 
      plugin_id: plugin_id)
      .first
    if s 
      log 'usersettings', s
      mysettings = cls.new.from_json s.data
    end
    mysettings 
  end

  def get_customer_settings(cls, customer_id, plugin_id)
    log 'method', 'get_customer_settings', 0
    s = CustomerSettings.where(
      customer_id: customer_id, 
      plugin_id: plugin_id)
      .first
    if s
      log 'customersettings', s
      mysettings = cls.new.from_json s.data
    end
    mysettings
  end
end
