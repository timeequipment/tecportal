class PluginServiceMasterController < ApplicationController
  before_filter :authenticate_user!
  layout "plugin"  

  @@plugin_id = 4

  def index
    log "\n\nmethod", 'index', 0
    
    # Get plugin settings for this user
    session[:settings] ||= get_settings(PluginServiceMaster::Settings, 
      current_user.id, 
      current_user.customer_id, 
      @@plugin_id)
    @settings = session[:settings]

    # Get schedules
    @scheds = PsvmSched.where(sched_date: startdate..enddate)

  rescue Exception => exc
    log 'exception', exc.message
    log 'exception backtrace', exc.backtrace
  end

  def settings
    log "\n\nmethod", 'settings', 0
    
      # Do stuff
  rescue Exception => exc
    log 'exception', exc.message
    log 'exception backtrace', exc.backtrace
  end

  def load_employees
    log "\n\nmethod", 'load_employees', 0
    

      # Request employees from AoD, in the background
      Delayed::Job.enqueue PluginServiceMaster::LoadEmployees.new(
        current_user.id,
        session[:settings])

      render json: true

  rescue Exception => exc
    log 'exception', exc.message
    log 'exception backtrace', exc.backtrace
  end

  def load_workgroups
    log "\n\nmethod", 'load_workgroups', 0
    

      # Request workgroup3 from AoD, in the background
      Delayed::Job.enqueue PluginServiceMaster::LoadWorkgroups.new(
        current_user.id,
        session[:settings],
        3)

      # Request workgroup5 from AoD, in the background
      Delayed::Job.enqueue PluginServiceMaster::LoadWorkgroups.new(
        current_user.id,
        session[:settings],
        5)

      render json: true

  rescue Exception => exc
    log 'exception', exc.message
    log 'exception backtrace', exc.backtrace
  end

  def load_scheds
    log "\n\nmethod", 'load_scheds', 0
    

  rescue Exception => exc
    log 'exception', exc.message
    log 'exception backtrace', exc.backtrace
  end

  def save_scheds
    log "\n\nmethod", 'save_scheds', 0
    
      # Do stuff
  rescue Exception => exc
    log 'exception', exc.message
    log 'exception backtrace', exc.backtrace
  end

  def filter
    log "\n\nmethod", 'filter', 0
    
      # Do stuff
  rescue Exception => exc
    log 'exception', exc.message
    log 'exception backtrace', exc.backtrace
  end

  def next_week
    log "\n\nmethod", 'next_week', 0
    
      # Do stuff
  rescue Exception => exc
    log 'exception', exc.message
    log 'exception backtrace', exc.backtrace
  end

  def prev_week
    log "\n\nmethod", 'prev_week', 0
    
      # Do stuff
  rescue Exception => exc
    log 'exception', exc.message
    log 'exception backtrace', exc.backtrace
  end

  def load_customer
    log "\n\nmethod", 'load_customer', 0
    
      # Do stuff
  rescue Exception => exc
    log 'exception', exc.message
    log 'exception backtrace', exc.backtrace
  end

  def save_customer
    log "\n\nmethod", 'save_customer', 0
    
      # Do stuff
  rescue Exception => exc
    log 'exception', exc.message
    log 'exception backtrace', exc.backtrace
  end

  private

  def get_scheds

  end
end
