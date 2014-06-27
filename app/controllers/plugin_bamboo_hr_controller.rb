class PluginBambooHrController < ApplicationController
  before_filter :authenticate_user!
  around_filter :catch_exceptions
  layout "plugin"  

  @@plugin_id = 5

  def index
    log __method__

    # Get plugin settings for this user
    cls = PluginBambooHr::Settings
    if session[:settings].class != cls
       session[:settings] = 
         get_settings(cls, 
          current_user.id, 
          current_user.customer_id, 
          @@plugin_id)
    end
  end

  def settings
    log __method__
  end

  def save_settings
    log __method__
  end
 
  def import_employees
    log __method__

    cache_save current_user.id, 'bhr_status', 'Initializing'
    cache_save current_user.id, 'bhr_progress', '10'

    # # Request employees from AoD, in the background
    # Delayed::Job.enqueue PluginBambooHr::ImportEmployees.new(
    #   current_user.id,
    #   session[:settings],
    #   params[:lastrun],
    #   params[:test_emp])

    # Request employees from AoD
    p = PluginBambooHr::ImportEmployees.new(
      current_user.id,
      session[:settings],
      params[:lastrun],
      params[:test_emp])
    p.perform
    
    render json: true
  end

  def progress
    log __method__
    
    progress = cache_get(current_user.id, 'bhr_progress') || 0
    status   = cache_get(current_user.id, 'bhr_status')   || ''
    messages = cache_get(current_user.id, 'bhr_messages') || ''

    render json: { progress: progress, status: status, messages: messages }.to_json
  end

  def catch_exceptions
    yield
  rescue Exception => exc
    
    log_exception exc

    # Alert the user
    flash.now[:alert] = exc.message
  end

end
