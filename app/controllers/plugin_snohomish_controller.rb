class PluginSnohomishController < ApplicationController
  before_filter :authenticate_user!
  layout "plugin"  

  @@plugin_id = 3

  def index
    log "\n\nmethod", 'index', 0
    begin
      
      # Get plugin settings for this user
      cls = PluginSnohomish::Settings
      if session[:settings].class != cls
         session[:settings] = 
           get_settings(cls, 
            current_user.id, 
            current_user.customer_id, 
            @@plugin_id)
      end

    rescue Exception => exc
      log 'exception', exc.message
      flash.now[:alert] = exc.message
    end
  end

  def settings
    log "\n\nmethod", 'settings', 0
    begin
      # If we just saved settings for a user
      if params[:settings_owner] && params[:settings_owner] != ''
        # Get their settings again
        session[:settings] = get_user_settings(PluginSnohomish::Settings,
          params[:settings_owner],
          @@plugin_id)
      else
        # Get the current user's settings
        params[:settings_owner] = current_user.id
        session[:settings] = get_user_settings(PluginSnohomish::Settings, 
          params[:settings_owner],
          @@plugin_id)  
      end

      # If we failed to get user settings
      if session[:settings].nil?
        # Get customer settings
        params[:settings_owner] = ''
        session[:settings] = get_customer_settings(PluginSnohomish::Settings,
          current_user.customer_id,
          @@plugin_id)
      end

      # And if we still failed, create new settings for this customer
      session[:settings] ||= PluginSnohomish::Settings.new

      # Make a view model
      @settingsvm = PluginSnohomish::SettingsVM.new({
        owner: params[:settings_owner], 
        account: session[:settings].account,
        username: session[:settings].username,
        password: session[:settings].password,
        reasoncode: session[:settings].reasoncode,
        testempid: session[:settings].testempid })

    rescue Exception => exc
      log 'exception', exc.message
      flash.now[:alert] = exc.message
    end
  end

  def save_settings
    log "\n\nmethod", 'save_settings', 0
    begin
      # Get settings for this plugin
      settingsvm = PluginSnohomish::SettingsVM.new(
        params[:plugin_snohomish_settings_vm])
      settings = PluginSnohomish::Settings.new(
        params[:plugin_snohomish_settings_vm])

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

  def round_hours
    #######################################################################
    ##
    ## Send supervisor edits to AoD to round hour grand totals
    ## to the nearest quarter of an hour for each day in a date range
    ## and for only transportation employees (WG1 == 99)
    ##
    #######################################################################

    log "\n\nmethod", 'round_hours', 0
    begin
      # ProgressBegin(2, "Creating connection")
      @aod = create_conn(session[:settings])
      #----------------------------------------------------------------
      # Get a list of the employees we'll be editing timecards for
      # (this will get just transportation emps or just the test emp 
      #  if one was specified in Settings)
      #-----------------------------------------------------------------

      # Progress("Getting employees")
      empids = get_employee_ids
      
      #--------------------------------------------------------------------------------------
      # Get a list of the dates we're editing, one for previous period and one for current
      #--------------------------------------------------------------------------------------

      # Make lists
      prevdates = []
      currdates = []

      # Get the pay periods
      # Progress("Getting pay periods")
      log 'Calling AoD',   :get_pay_period_class_data
      response = @aod.call(:get_pay_period_class_data, message: { 
        payPeriodClassNum: 1 })  
      @payperiods = camel_case_hash_keys response.body[:t_ae_pay_period_info]
      @prevstart = @payperiods["PrevStart"].to_datetime
      @prevend   = @payperiods["PrevEnd"]  .to_datetime
      @currstart = @payperiods["CurrStart"].to_datetime
      @currend   = @payperiods["CurrEnd"]  .to_datetime

      # Get the date range the user picked
      @begindate = Date.strptime(params[:begindate], "%m/%d/%Y")
      @enddate   = Date.strptime(params[:enddate],   "%m/%d/%Y")

      # For each day in the date range, populate the lists
      @begindate.upto @enddate do |day|
        if @prevstart <= day && day <= @prevend
          prevdates << day
        elsif @currstart <= day && day <= @currend
          currdates << day
        end
      end

      log 'empids', empids
      log 'payperiods', @payperiods
      log 'prevstart', @prevstart
      log 'prevend', @prevend
      log 'currstart', @currstart
      log 'currend', @currend
      log 'begindate', @begindate
      log 'enddate', @enddate

      # ProgressBegin(empids.count * 2, "Deleting edits")

      #----------------------------------
      # For each employee
      #----------------------------------

      empids.each do |empid|
        #----------------------------------
        # Delete edits in previous period
        #----------------------------------

        # Progress("Deleting edits for employee id:  " + empid)
        if prevdates.count > 0
          delete_edits 'drPrevPeriod', prevdates, empid
        end

        #----------------------------------
        # Delete edits in current period
        #----------------------------------

        # Progress("Deleting edits for employee id:  " + empid)
        if currdates.count > 0
          delete_edits 'drCurrPeriod', currdates, empid
        end
      end

      a = params[:justdeleteedits]
      if a.nil? || a == "false"
        #----------------------------------------------
        # Get the total hours worked for all dates
        #----------------------------------------------
        # Get our new date range after comparing to pay periods
        # in case the original had dates outlying the prev or curr period.
       
        prevdates.concat currdates
        @begindate = prevdates[0]
        @enddate = prevdates[-1]

        # Get paylines, and then totals from them
        # ProgressBegin(3, "Getting hours worked")
        paylines = get_pay_lines
        totals = get_totals paylines

        # Get everyone's last punch for these dates
        # so we know when the eff. times need to be for the edits
        # Progress("Preparing edits")
        totals = get_last_punches(totals, empids)

        log 'totals', totals

        #-------------------------------------------
        # Send new edits for these totals
        #-------------------------------------------

        # Progress("Sending edits")
        log 'settings', session[:settings]
        send_edits totals
      end
    ensure
      # ProgressEnd("Done")
    end
  end

  private

  def get_employee_ids
    empids = []

    # If we're testing on just one employee
    if session[:settings].testempid != ""
      # Get the id for the test employee
      empids << session[:settings].testempid
    else
      # Get all active emps from AoD
      log 'Calling AoD',   :get_active_employees_list
      response = @aod.call(:get_active_employees_list, message: {})  
      @emps = response.body[:t_ae_employee_basic]

      # Get the id's for just the transportation emps
      @emps.each do |emp|
        if emp[:wg1].to_s == '99'
          empids << emp[:emp_id]
        end
      end
    end
    empids
  end

  def delete_edits(payperiod, dates, empid)
    #-----------------------------------------------------------------------------
    # Delete edits in this pay period, made on these dates, for this employee
    #-----------------------------------------------------------------------------

    deletions = false

    # Get their edits for this period (must be previous or current to get SiteID)
    log 'Calling AoD',   :extract_employee_edits_by_id_num
    response = @aod.call(:extract_employee_edits_by_id_num, message: {
      iDNum: empid,
      dateRangeEnum: payperiod,
      minDate: '',
      maxDate: '' }) 
    @edits = response.body[:t_ae_edit]

    log 'edits', @edits

    @edits.each do |edit|
      # If the edit was made by this program, and was within these dates
      edit = camel_case_hash_keys edit
      log 'edit', edit
      log 'session[:settings].reasoncode ', session[:settings].reasoncode 
      if edit["ReasonCodeId"].to_s == session[:settings].reasoncode.to_s &&
         dates.include?(edit["EffDate"].to_datetime)
        # Delete it
        log 'edit being deleted', edit
        log 'Calling AoD',   :delete_time_card_edit
        response = @aod.call(:delete_time_card_edit, 
          message: {
            aeEdit: {
              empName:       edit["EmpName"],
              lastName:      edit["LastName"],
              firstName:     edit["FirstName"],
              initial:       edit["Initial"],
              empID:         edit["EmpId"],
              sSN:           edit["Ssn"],
              badge:         edit["Badge"],
              filekey:       edit["Filekey"],
              activeStatus:  edit["ActiveStatus"],
              dateOfHire:    edit["DateOfHire"],
              wG1:           edit["Wg1"],
              wG2:           edit["Wg2"],
              wG3:           edit["Wg3"],
              wG4:           edit["Wg4"],
              wG5:           edit["Wg5"],
              wG6:           edit["Wg6"],
              wG7:           edit["Wg7"],
              wGDescr:       edit["WgDescr"],
              editNameDescr: edit["EditNameDescr"],
              editOpDescr:   edit["EditOpDescr"],
              accountCode:   edit["AccountCode"],
              effDate:       edit["EffDate"],
              effTime:       edit["EffTime"],
              editTimeStamp: edit["EditTimeStamp"],
              hours:         edit["Hours"],
              editRate:      edit["EditRate"],
              editDollars:   edit["EditDollars"],
              hoursHund:     edit["HoursHund"],
              editType:      edit["EditType"],
              clkSup:        edit["ClkSup"],
              siteID:        edit["SiteId"],
              payDesID:      edit["PayDesId"],
              prevPayDesID:  edit["PrevPayDesId"],
              reasonCodeID:  edit["ReasonCodeId"],
              editWG1:       edit["EditWg1"],
              editWG2:       edit["EditWg2"],
              editWG3:       edit["EditWg3"],
              editWG4:       edit["EditWg4"],
              editWG5:       edit["EditWg5"],
              editWG6:       edit["EditWg6"],
              editWG7:       edit["EditWg7"],
              editWGDescr:   edit["EditWgDescr"]
            },
            recomputeImmediately: true }) # true is important to recompute timecard
        deletions = true
      end
    end

    # Recompute this employee
    if deletions
      log 'Calling AoD',   :recompute_employee_by_id_num
      response = @aod.call(:recompute_employee_by_id_num, message: {
        iDNum: empid,
        payPeriodEnum: (payperiod == 'drPrevPeriod' ? 'ppePrevious' : 'ppeCurrent') })
    end
  end

  def get_pay_lines
    # Init vars
    payrollRecords = []
    paylines       = []
    errormessages  = []

    # Prepare request for payroll data
    daterange = "custom{fs}" + @begindate.strftime('%m/%d/%Y') + 
                      "{fs}" + @enddate.strftime('%m/%d/%Y')

    # Send request, get response
    log 'Calling AoD',   :get_manually_selected_calculated_data
    response = @aod.call(:get_manually_selected_calculated_data, 
      message: {
        aeExchangeStruct: {
          fieldSep: "{fs}",
          lineSep: "{ls}",
          rawData: 
            "daterange{fs}" + daterange + "{ls}" + 
            "calculation{fs}assaved{ls}" + 
            "noactivity{fs}skip{ls}" +
            "dataset{fs}daily{ls}" + 
            "Hyperquery{fs}All Employees" } })

    exch = response.body[:t_ae_exchange_struct]

    # Parse response
    paylines = parse_ae_exchange_struct(exch)

    # Filter out all emps that aren't transportation emps
    paylines = filter_pay_lines(paylines)

    paylines
  end

  def parse_ae_exchange_struct(ae_exch_struct)
    #---------------------------------------------------------------
    # Parse the RawData in ae_exch_struct into a list of pay lines
    #---------------------------------------------------------------
    paylines = []
    rawdata = ae_exch_struct[:raw_data]

    if rawdata.is_a? String
      lines = rawdata.split('{ls}')
      lines.each do |line|
        fields = line.split '{fs}' 

        if fields.length > 0 && fields[0] == "PAYLINE"
          payline = {
            emp_id:        fields[1],
            emp_name:      fields[2],
            ssn:           fields[3],
            badge:         fields[4].to_i,
            filekey:       fields[5].to_i,
            active_status: fields[6].to_i,
            date_of_hire:  fields[7],
            wg_descr:      fields[8],
            wg1:           fields[9].to_i,
            wg2:           fields[10].to_i,
            wg3:           fields[11].to_i,
            wg4:           fields[12].to_i,
            wg5:           fields[13].to_i,
            wg6:           fields[14].to_i,
            wg7:           fields[15].to_i,
            base_rate:     fields[16].to_f,
            date:          fields[17],
            pay_des_num:   fields[18].to_i,
            pay_des_name:  fields[19],
            hours:         fields[20].to_i,
            hours_hund:    fields[21].to_f,
            wrk_rate:      fields[22].to_f,
            dollars:       fields[23].to_f,
            wrk_wg_descr:  fields[24],
            wrk_wg1:       fields[25].to_i,
            wrk_wg2:       fields[26].to_i,
            wrk_wg3:       fields[27].to_i,
            wrk_wg4:       fields[28].to_i,
            wrk_wg5:       fields[29].to_i,
            wrk_wg6:       fields[30].to_i,
            wrk_wg7:       fields[31].to_i,
          }
          paylines << payline 
        else
          errormessages << "Unable to parse this AoD response:  \r\n" + line
        end
      end
    end
    paylines
  end

  def filter_pay_lines(paylines)
    #----------------------------------------------------------
    # Filter out all emps that aren't transportation emps
    #----------------------------------------------------------

    # If we're testing on just one employee
    if session[:settings].testempid != ""
      # Filter out all emps except the test employee
      paylines.delete_if { 
        |x| x[:emp_id] != session[:settings].testempid }
    else
      # Filter out all emps that aren't transportation emps
      paylines.delete_if { |x| x[:wg1] != 99 }
    end
    paylines
  end

  def get_totals(paylines)
    # Query pay lines to get worked hours totals
    totals = paylines.group_by{ |a| [
      a[:emp_id],
      a[:date],
      a[:wg1] ] }
        .map { |p, paylines|
          y = {
            emp_id:        p[0].to_s,
            date:          p[1].to_datetime,
            total_minutes: paylines.sum { |b| b[:hours].to_f },
            last_punch:    DateTime.new(1900, 1, 1, 0, 0, 0) } }
  end

  def get_last_punches(totals, empids)
    #--------------------------------------------------------------------------------
    # This method gets the last punch of the day for each employee.
    # We get the last punch because for 1st and 2nd shifters this will be the end
    # of their day, while for 3rd shifters this will be the beginning of their day,
    # so in both cases we're getting a punch time on the right day.  If we would do
    # the first punch of the day, then it would fail for 3rd shifters as the first
    # punch of a day is really the last punch of the previous day.  
    #--------------------------------------------------------------------------------

    # Get employee punches for our date range
    log 'Calling AoD',   :extract_ranged_transactions_using_hyper_query
    response = @aod.call(:extract_ranged_transactions_using_hyper_query, 
      message: {
        hyperQueryName: 'All Employees',
        dateRangeEnum: 'drCustom',
        minDate: @begindate.strftime('%Y-%m-%d'),
        maxDate: @enddate.strftime('%Y-%m-%d') })
    punches = response.body[:t_ae_emp_transaction]
  
    # Group them up by emp and date, and get the last punch
    punchTotals = punches.group_by{ |a| [
      a[:emp_id],
      a[:time_stamp].to_date ]}
        .map { |p, punches|
          y = {
            emp_id:      p[0].to_s,
            date:        p[1].to_datetime,
            last_punch:  punches.max { |b| b[:time_stamp].to_date } } }

    # Apply the last punch to the totals we've already gotten
    totals.each do |total|
      punchTotals.each do |punchTotal|
        if total[:emp_id] == punchTotal[:emp_id] && 
           total[:date].strftime('%D') == punchTotal[:date].strftime('%D')
          total[:last_punch] = punchTotal[:last_punch][:time_stamp].to_datetime
          break
        end
      end
    end

    totals
  end

  def send_edits(totals)
    #--------------------------------------------------------------
    # Send new edits for these totals 
    # which will round hours to the nearest quarter of an hour
    #--------------------------------------------------------------

    # For each employee's total worked hours
    # ProgressBegin(totals.count, "Sending Edits")
    totals.each do |total|
      # Progress("Sending edits for employee id:  " + total.empid)
      roundAmt = 0

      # Get the nearest 15 minutes less than total minutes and the distance to it
      distance = total[:total_minutes] % 15
      nearest = total[:total_minutes] - distance

      log 'distance', distance
      log 'nearest', nearest

      # If it's already rounded, go to the next employee's total
      if distance == 0
        next
      end

      # If the distance is > 7 minutes
      if distance > 7
        # Then round up to the next 15 minutes
        roundAmt = 15 - distance
      else
        # Else round down
        roundAmt = -distance
      end

      log 'roundAmt', roundAmt

      # Send edit to AoD
      log 'Calling AoD',   :perform_time_card_edit
      response = @aod.call(:perform_time_card_edit, 
        message: {
          aeEdit: {
            empID:        total[:emp_id],
            badge:        0,
            activeStatus: 0,
            wG1:          0,
            wG2:          0,
            wG3:          0,
            wG4:          0,
            wG5:          0,
            wG6:          0,
            wG7:          0,
            effDate:      total[:date].strftime('%Y-%m-%d'),
            effTime:      total[:last_punch].strftime('%T'),
            hours:        roundAmt.to_i,
            editRate:     0,
            editDollars:  0,
            hoursHund:    0,
            editType:     2,
            clkSup:       0,
            siteID:       0,
            payDesID:     1,
            prevPayDesID: 0,
            reasonCodeID: session[:settings].reasoncode,
            editWG1:      0,
            editWG2:      0,
            editWG3:      0,
            editWG4:      0,
            editWG5:      0,
            editWG6:      0,
            editWG7:      0,
          },
          recomputeImmediately: true }) # true is important to recompute timecard
    end
  end
end
