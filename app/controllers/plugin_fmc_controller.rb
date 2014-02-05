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
      log 'settings.paycodemappings', JSON.parse(settings.paycodemappings)

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

      log 'settingsvm.paycodemappings', JSON.parse(settingsvm.paycodemappings)

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
      # Connect to AoD
      aod = create_conn(session[:settings])
      
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

          # mappings = JSON.parse(session[:settings].paycodemappings)
          # log 's', session[:settings].paycodemappings

          # log 'settings', session[:settings]
          # return


      # Get pay period summaries from AoD
      response = aod.call(
        :extract_pay_period_summaries, message: { 
          payPeriodEnum: pay_period,
          payLineStatEnum: "plsCalculated", 
          calcedDataTypeEnum: "cdtNormal",
          noActivityInclusion: "naiSkip" })  
      paylines = response.body[:t_ae_pay_line]

      # Get settings
      if session[:settings]

        # Get paycodemappings
        if session[:settings].paycodemappings
          mappings = JSON.parse(session[:settings].paycodemappings)
        end

        # Get includeumapped
        includeunmapped = true
        if session[:settings].includeunmapped && 
           session[:settings].includeunmapped == "0"
          includeunmapped = false
        end

        mappings.each do |mapping|
          log 'mapping', mapping
          log 'mapping class', mapping.class
        end

        # Convert the paylines to payroll records
        payrecords = []
        paylines.each do |payline|
          # If there is a pay code mapping for this paydesnum
          paydesnum = payline[:pay_des_num].to_s
          wg3       = payline[:wrk_wg3].to_s
          mapping   = get_paycode_mapping(mappings, paydesnum, wg3)

          if includeunmapped 
            mapping ||= [0, 0, 0, 0]
          end

          if mapping
            p = PluginFMC::PayrollRecord.new
            p.employeeid = payline[:emp_id]
            p.paycode    = mapping[2]
            p.hours      = payline[:hours_hund].to_s.to_f
            p.dollars    = payline[:dollars].to_s.to_f
            p.rate       = payline[:wrk_rate]  .to_s.to_f
            p.transactiondate = (params[:payperiod] == "0" ? 
              session[:prevend].to_s :
              session[:currend].to_s)
            p.trxnumber  = ''
            p.btnnext    = '1'

            if p.hours + p.dollars == 0 
              next
            end

            if p.paycode.nil? 
              p.paycode = 'Unmapped - PayDes: ' + paydesnum + ' - Wg3: ' + wg3
            end

            # Add this payroll record to our array
            payrecords << p
          end
        end
        
        # Group results by all fields, total up hours
        results = payrecords.group_by{ |a| [
          a.employeeid,
          a.paycode,
          a.rate,
          a.transactiondate ] }
            .map { |p, payrecords|
              y = PluginFMC::PayrollRecord.new
              y.employeeid      = p[0].to_s
              y.paycode         = p[1].to_s
              y.hours           = payrecords.sum { |b| b.hours.to_f }
              y.dollars         = payrecords.sum { |b| b.dollars.to_f }
              y.rate            = p[2].to_s.to_f
              y.transactiondate = p[3].to_s
              y.trxnumber = ''
              y.btnnext = '1'
              y } 

        # Create header for payroll records
        header = 'Employee ID,Pay Code,Amount,Rate,Transaction Date,Trx Number,Btn Next'

        # Create file, from header and payroll records
        session[:fmc_payroll_file] = 
          header + "\n" + results.join("\n")
      end

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
      flash.now[:alert] = exc.message
    end
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

  private

    def get_paycode_mapping(mappings, paydesnum, wg3)
      mappings.each do |mapping|
        if mapping[0] == paydesnum && mapping[1] == wg3
          return mapping
        end
      end
      nil
    end

end
