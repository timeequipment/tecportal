class PluginBambooHrController < ApplicationController
  before_filter :authenticate_user!
  layout "plugin"  

  @@plugin_id = 5

  def index
    begin
      log "\n\nmethod", __method__, 0

      # Get plugin settings for this user
      cls = PluginBambooHr::Settings
      if session[:settings].class != cls
         session[:settings] = 
           get_settings(cls, 
            current_user.id, 
            current_user.customer_id, 
            @@plugin_id)
      end

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def settings
  end

  def save_settings
  end
 
  def import_employees
    begin
      log "\n\nmethod", __method__, 0

      cache_save current_user.id, 'bhr_status', 'Initializing'
      cache_save current_user.id, 'bhr_progress', '10'

      # Request employees from AoD, in the background
      Delayed::Job.enqueue PluginBambooHr::ImportEmployees.new(
        current_user.id,
        session[:settings],
        params[:lastrun])

      # # Request employees from AoD
      # p = PluginBambooHr::ImportEmployees.new(
      #   current_user.id,
      #   session[:settings],
      #   params[:lastrun])
      # p.perform
      
      render json: true

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def progress
    progress = cache_get(current_user.id, 'bhr_progress') || 0
    status   = cache_get(current_user.id, 'bhr_status')   || ''
    messages = cache_get(current_user.id, 'bhr_messages') || ''

    render json: { progress: progress, status: status, messages: messages }.to_json
  end

end
