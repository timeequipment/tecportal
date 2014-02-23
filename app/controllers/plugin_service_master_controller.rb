class PluginServiceMasterController < ApplicationController
  before_filter :authenticate_user!
  layout "plugin"  

  @@plugin_id = 4

  def index
    log "\n\nmethod", 'index', 0
    begin
      # Get the current week
      week = get_week

      # Get the current workgroup filters 
      filters = get_filters

      # Get the schedules from AoD for this week, for these workgroups
      @scheds = get_scheds

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def settings
    log "\n\nmethod", 'settings', 0
    begin
      # Do stuff
    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def load_scheds
    log "\n\nmethod", 'load_scheds', 0
    begin
      render 'index'

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def save_scheds
    log "\n\nmethod", 'save_scheds', 0
    begin
      # Do stuff
    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def filter
    log "\n\nmethod", 'filter', 0
    begin
      # Do stuff
    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def next_week
    log "\n\nmethod", 'next_week', 0
    begin
      # Do stuff
    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def prev_week
    log "\n\nmethod", 'prev_week', 0
    begin
      # Do stuff
    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def load_customer
    log "\n\nmethod", 'load_customer', 0
    begin
      # Do stuff
    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def save_customer
    log "\n\nmethod", 'save_customer', 0
    begin
      # Do stuff
    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  private

  def get_scheds

  end
end