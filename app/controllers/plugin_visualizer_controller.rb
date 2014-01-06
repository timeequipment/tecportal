class PluginVisualizerController < ApplicationController
  before_filter :authenticate_user!
  layout "plugin"  

  @@plugin_id = 1

  def index
    log 'method', 'index', 0
    begin
      # Connect to AoD
      aod = create_conn

      # Get pay periods from AoD
      response = aod.get_pay_period_class_data(
        message: { payPeriodClassNum: 1 })  
      @payperiods = response.body[:t_ae_pay_period_info]
      @prevstart = @payperiods[:prev_start].to_datetime.strftime('%-m-%d-%Y')
      @prevend   = @payperiods[:prev_end]  .to_datetime.strftime('%-m-%d-%Y')
      @currstart = @payperiods[:curr_start].to_datetime.strftime('%-m-%d-%Y')
      @currend   = @payperiods[:curr_end]  .to_datetime.strftime('%-m-%d-%Y')
    rescue Exception => exc
      log 'exception', exc.message
      flash.now[:alert] = 'Unable to connect to AoD. Please check settings.'
    end
  end

  def settings
    log 'method', 'settings', 0
    begin
      # If we just saved settings for someone
      if params[:settings_owner] && params[:settings_owner] != ''
        # Get their settings again
        settings = get_user_settings(params[:settings_owner])
      else
        # Get the current user's settings
        params[:settings_owner] = current_user.id
        settings = get_user_settings(params[:settings_owner])  
      end

      # If we failed to get user settings
      if settings.nil?
        # Get customer settings
        params[:settings_owner] = ''
        settings = get_customer_settings  
      end

      # And if we still failed, create new settings for this customer
      settings ||= PluginVisualizer::Settings.new

      # Make a view model
      @settingsvm = PluginVisualizer::SettingsVM.new({
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
    log 'method', 'save_settings', 0
    begin
      # Get settings for this plugin
      settingsvm = PluginVisualizer::SettingsVM.new(
        params[:plugin_visualizer_settings_vm])
      settings = PluginVisualizer::Settings.new(
        params[:plugin_visualizer_settings_vm])

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

  def create_report
    log 'method', 'create_report', 0
    begin
      # Connect to AoD
      aod = create_conn()
      
      # Get pay period chosen
      if params[:payperiod] == "0"
        date_range = "drPrevPeriod" 
      else
        date_range = "drCurrPeriod" 
      end

      # # Get hyperqueries from AoD
      # response = aod.get_hyper_queries_simple()
      # @hyper_qs = response.body[:get_hyper_queries_simple_response] \
      #   [:return][:item]

      # Get schedules from AoD
      response = aod.extract_ranged_schedules_using_hyper_query(
        message: { 
          hyperQueryName: "All Employees",
          dateRangeEnum: date_range, 
          minDate: "",
          maxDate: "" })  
      schedules = response.body[:t_ae_schedule]

      # Make an array of sched records
      @schedrecords = Array.new

      # Convert the schedules to sched records
      schedules.each do |schedule|
        s = PluginVisualizer::SchedRecord.new
        s.lastname = schedule[:last_name]
        s.firstname = schedule[:first_name]
        s.employeeid = "J5X" + schedule[:emp_id].to_s.rjust(6, '0')
        s.intime = (schedule[:sch_date].to_s + " " + 
          schedule[:sch_start_time].to_s).to_datetime
        s.outtime = (schedule[:sch_date].to_s + " " + 
          schedule[:sch_end_time].to_s).to_datetime
        s.hours = schedule[:sch_hours_hund]
        s.earningscode = ""
        s.lunchplan = ""
        s.prepaiddate = ""
        s.workedflag = "TRUE"
        s.scheduletype = "Recurring"
        s.timezone = "PST"  

        # Offset 1 day for 3rd shifters whose end time would be 
        # numerically less than their start time
        if s.outtime <= s.intime
          s.outtime = s.outtime + 1
        end

        # If this is a benefit or planned absence schedule
        if schedule[:sch_type] == "steAbsPlnBen" || 
           schedule[:sch_type] == "steAbsPlnPayDes"
         
          aodnum = schedule[:benefit_id]
          ispaydes = false

          if schedule[:sch_type] == "steAbsPlnPayDes"
            aodnum = schedule[:pay_des_id]
            ispaydes = true
          end

          # Set the worked flag and lookup the earnings code for it
          s.workedflag = "FALSE"
          #s.earningscode = Helper.LookupBenefitMapping(isPayDes, aodNum);
        end

        # If a sched pattern did NOT generate this schedule
        if schedule[:sch_patt_id] == 0
          # Set the sched type
          s.scheduletype = "Deviation"
        end

        # Add this sched record to our array
        @schedrecords << s
      end

      # Create header for sched records
      @schedheader = 'Last Name,First Name,Employee ID,In time,Out time,Hours,Earnings Code,Scheduled Department,Lunch Plan,Pre-Paid Date,Worked Flag,Schedule Type,TimeZone,Department'

      # Create file, from header and sched records
      session[:schedfile] = 
        @schedheader + "\n" + @schedrecords.join("\n")

    rescue Exception => exc
      log 'exception', exc.message
      flash.now[:alert] = exc.message
    end
  end

  def download_report
    begin
      log 'method', 'download_report', 0
      send_data session[:schedfile].to_s, 
        :filename => "schedules.csv", 
        :type => "text/plain" 
    rescue Exception => exc
      log 'exception', exc.message
      flash.now[:alert] = exc.message
    end
  end

  private

    def create_conn
      log 'method', 'create_conn', 0
      # Get plugin settings
      settings = get_user_settings(current_user.id) 
      settings ||= get_customer_settings
      settings ||= PluginVisualizer::Settings.new
      log 'aod account', settings.account
      log 'aod username', settings.username
      log 'aod password', settings.password

      # Return interface to AoD
      ApplicationHelper::AodInterface.new(
        settings.account, 
        settings.username, 
        settings.password)
    end

    def get_user_settings(user_id)
      log 'method', 'get_user_settings', 0
      s = UserSettings.where(
        user_id: user_id, 
        plugin_id: @@plugin_id)
        .first
      if s 
        log 'usersettings', s
        mysettings = PluginVisualizer::Settings.new.from_json s.data
      end
      mysettings 
    end

    def get_customer_settings
      log 'method', 'get_customer_settings', 0
      s = CustomerSettings.where(
        customer_id: current_user.customer_id, 
        plugin_id: @@plugin_id)
        .first
      if s
        log 'customersettings', s
        mysettings = PluginVisualizer::Settings.new.from_json s.data
      end
      mysettings
    end

end
