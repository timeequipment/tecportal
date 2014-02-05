class ApplicationController < ActionController::Base
  protect_from_forgery
  require 'awesome_print'
  require 'savon'

  $debug_msg = ''
  $debug_hash = {}

  def awesome_print_test
    test = {
      array: ["apple", "orange", "banana", "grape", "kiwi"],
      true_: true,
      false_: false,
      class_: 23.class,
      nilclass: nil,
      fixnum: 42,
      float: 3.1415926,
      rational: Rational(3, 4),
      bigdecimal: BigDecimal.new("423859829938.234"),
      date: DateTime.new(1980, 1, 3, 0, 0, 0),
      time: Time.new(2002, 10, 31),
      string: "This is a String!",
      symbol: :this_symbol,
      hash: { a1: "this", a2: "that", a3: %w(forty two), a4: { b1: 45, b2: 29, b3: 31 } },
      object: UserSettings,
      methods_args_classes: 23.methods,
    }
    log 'awesome print test', test
  end

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

  def create_conn(settings)
    log 'method', 'create_conn', 0
    log 'aod account', settings.account
    log 'aod username', settings.username
    log 'aod password', settings.password

    namespaces = {
      "xmlns:soapenc" => "http://schemas.xmlsoap.org/soap/encoding/", 
      "xmlns:types" => "http://tempuri.org/encodedTypes", 
      "xmlns:q1" => "urn:AeXMLBridgeIntf-IAeXMLBridge",
    }

    ccased = lambda { |key| key.camelize }

    # Return interface to AoD
    Savon.client(
      wsdl: "https://#{ settings.account }.attendanceondemand.com:8192/cc1.aew/wsdl/IAeXMLBridge", 
      endpoint: "https://#{ settings.account }.attendanceondemand.com:8192/cc1exec.aew/soap/IAeXMLBridge", 
      basic_auth: [settings.username, settings.password],
      open_timeout: 300,
      read_timeout: 300,
      log: true,
      log_level: :info, # use :debug to log HTTP messages or :info to not
      pretty_print_xml: true,
      convert_request_keys_to: :camelcase,
      namespaces: namespaces,
      namespace_identifier: :q1,
      env_namespace: :soap)
  end

  def camel_case_hash_keys(h)
    # Convert all the keys in the hash to strings and then camel-case them
    # Return a new hash
    Hash[h.map{ |k,v| [k.to_s.camelize, v] } ]
  end

  def get_settings(cls, user_id, customer_id, plugin_id)
    log 'method', 'get_settings', 0
    settings = get_user_settings(cls, user_id, plugin_id) 
    settings ||= get_customer_settings(cls, customer_id, plugin_id)
    settings ||= cls.new
    settings
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
