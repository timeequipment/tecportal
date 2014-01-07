class PluginFmcController < ApplicationController
  before_filter :authenticate_user!
  layout "plugin"  

  @@plugin_id = 2

  def index
    log "\n\n method", 'index', 0
    begin
      # Connect to AoD
      aod = create_conn(PluginFMC::Settings, 
        current_user.id, 
        current_user.customer_id, 
        @@plugin_id)

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
      flash.now[:alert] = 'Unable to connect to AoD. Please check settings.'
    end
  end

  def settings
    log "\n\n method", 'settings', 0
    begin
      # If we just saved settings for someone
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

      # Make a view model
      @settingsvm = PluginFMC::SettingsVM.new({
        owner: params[:settings_owner], 
        account: settings.account,
        username: settings.username,
        password: settings.password })

    rescue Exception => exc
      log 'exception', exc.message
      flash.now[:alert] = exc.message
    end
  end

  def save_settings
    log "\n\n method", 'save_settings', 0
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
      flash.now[:alert] = exc.message
    end
    redirect_to action: 'settings'
  end

  def create_export
    log "\n\n method", 'create_export', 0
    begin
      # Connect to AoD
      aod = create_conn(PluginFMC::Settings, 
        current_user.id, 
        current_user.customer_id, 
        @@plugin_id)
      
      # Get pay period chosen
      if params[:payperiod] == "0"
        pay_period = "ppePrevious" 
      else
        pay_period = "ppeCurrent" 
      end

      # # Get hyperqueries from AoD
      # response = aod.get_hyper_queries_simple()
      # @hyper_qs = response.body[:get_hyper_queries_simple_response] \
      #   [:return][:item]

      # Get pay period summaries from AoD
      response = aod.call(
        :extract_pay_period_summaries, message: { 
          payPeriodEnum: pay_period,
          payLineStatEnum: "plsCalculated", 
          calcedDataTypeEnum: "cdtNormal",
          noActivityInclusion: "naiSkip" })  
      paylines = response.body[:t_ae_pay_line]

      # Make an array of payroll records
      @payrecords = Array.new

      # Convert the paylines to payroll records
      paylines.each do |payline|
        p = PluginFMC::PayrollRecord.new
        p.employeeid = payline[:emp_id]
        p.paycode = payline[:pay_des_name]
        p.hours = payline[:hours_hund].to_s.to_f
        p.rate = payline[:wrk_rate].to_s.to_f
        p.transactiondate = (params[:payperiod] == "0" ? 
          session[:prevend].to_s :
          session[:currend].to_s)
        p.trxnumber = ''
        p.btnnext = '1'

        # Add this payroll record to our array
        @payrecords << p
      end

      # Create header for payroll records
      @header = 'Employee ID,Pay Code,Hours,Rate,Transaction Date,Trx Number,Btn Next'

      # Create file, from header and payroll records
      session[:fmc_payroll_file] = 
        @header + "\n" + @payrecords.join("\n")

    rescue Exception => exc
      log 'exception', exc.message
      flash.now[:alert] = exc.message
    end
  end

  def download_file
    begin
      log "\n\n method", 'download_file', 0
      send_data session[:fmc_payroll_file].to_s, 
        :filename => "payroll.csv", 
        :type => "text/plain" 

    rescue Exception => exc
      log 'exception', exc.message
      flash.now[:alert] = exc.message
    end
  end

end
