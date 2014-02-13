class PluginFmcController < ApplicationController
  before_filter :authenticate_user!
  layout "plugin"  

  @@plugin_id = 2

  def index
    log "\n\nmethod", 'index', 0
    begin
      # Get plugin settings for this user
      session[:settings] = get_settings(PluginFMC::Settings, 
        current_user.id, 
        current_user.customer_id, 
        @@plugin_id)

      # Connect to AoD
      aod = create_conn(session[:settings])

      # Get pay periods from AoD
      response = aod.call(
        :get_pay_period_class_data, message: { 
          payPeriodClassNum: 1 })  
      @payperiods = response.body[:t_ae_pay_period_info]
      @prevstart = @payperiods[:prev_start].to_datetime.strftime('%-m-%d-%Y')
      @prevend   = @payperiods[:prev_end]  .to_datetime.strftime('%-m-%d-%Y')
      @currstart = @payperiods[:curr_start].to_datetime.strftime('%-m-%d-%Y')
      @currend   = @payperiods[:curr_end]  .to_datetime.strftime('%-m-%d-%Y')
      session[:prevend] = @prevend
      session[:currend] = @currend

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
      flash.now[:alert] = 'Unable to connect to AoD. Please check settings.'
    end
  end

  def settings
    log "\n\nmethod", 'settings', 0
    begin
      # If we just saved settings for a user
      if params[:settings_owner] && params[:settings_owner] != ''
        # Get their settings again
        settings = get_user_settings(PluginFMC::Settings,
          params[:settings_owner],
          @@plugin_id)
      else
        # Get the current user's settings
        params[:settings_owner] = current_user.id
        settings = get_user_settings(PluginFMC::Settings, 
          params[:settings_owner],
          @@plugin_id)  
      end

      # If we failed to get user settings
      if settings.nil?
        # Get customer settings
        params[:settings_owner] = ''
        settings = get_customer_settings(PluginFMC::Settings,
          current_user.customer_id,
          @@plugin_id)
      end

      # And if we still failed, create new settings for this customer
      settings ||= PluginFMC::Settings.new

      # Set defaults for pay code mappings
      if settings.paycodemappings.nil? || 
         settings.paycodemappings.blank?
        settings.paycodemappings = '[]'
      end

      # Make a view model
      @settingsvm = PluginFMC::SettingsVM.new({
        owner: params[:settings_owner], 
        account: settings.account,
        username: settings.username,
        password: settings.password,
        includeunmapped: settings.includeunmapped,
        paycodemappings: settings.paycodemappings })

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
      flash.now[:alert] = exc.message
    end
  end

  def save_settings
    log "\n\nmethod", 'save_settings', 0
    begin
      # Get settings for this plugin
      settingsvm = PluginFMC::SettingsVM.new(
        params[:plugin_fmc_settings_vm])
      settings = PluginFMC::Settings.new(
        params[:plugin_fmc_settings_vm])

      # Save these settings for the customer
      if settingsvm.owner.blank?
        s = CustomerSettings.where(
          customer_id: current_user.customer_id, 
          plugin_id: @@plugin_id).first_or_initialize
        s.data = settings.to_json
        s.save!
      else
        # Save these settings for the user
        s = UserSettings.where(
          user_id: settingsvm.owner.to_i, 
          plugin_id: @@plugin_id).first_or_initialize
        s.data = settings.to_json
        s.save!
      end

      params[:settings_owner] = settingsvm.owner
      flash.now[:message] = "Settings saved."

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
      flash.now[:alert] = exc.message
    end
    redirect_to action: 'settings'
  end

  def create_export
    log "\n\nmethod", 'create_export', 0
    begin

      cache_save current_user.id, 'fmc_status', 'Initializing'
      cache_save current_user.id, 'fmc_progress', '10'
      sleep 1

      Delayed::Job.enqueue PluginFMC::CreateExport.new(
        current_user.id,
        session[:settings],
        session[:prevend],
        session[:currend],
        params[:payperiod])

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
      flash.now[:alert] = exc.message
    end
  end

  def progress
    progress = cache_get current_user.id, 'fmc_progress'
    status   = cache_get current_user.id, 'fmc_status'
    export   = cache_get current_user.id, 'fmc_export'

    if progress != '100'
      render json: { progress: progress, status: status }.to_json
    else
      render json: true
    end
  end

  def finish
    cache_save current_user.id, 'fmc_progress', '0'
    cache_save current_user.id, 'fmc_status', ''
  end

  def download_file
    begin
      log "\n\nmethod", 'download_file', 0
      send_data session[:fmc_payroll_file].to_s, 
        :filename => "payroll.csv", 
        :type => "text/plain" 

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
      flash.now[:alert] = exc.message
    end
  end

end
