class PluginSnohomishController < ApplicationController
  before_filter :authenticate_user!
  layout "plugin"  

  @@plugin_id = 3

  def index
    log "\n\nmethod", 'index', 0
    begin
      # Get plugin settings for this user
      session[:settings] = get_settings(PluginSnohomish::Settings, 
        current_user.id, 
        current_user.customer_id, 
        @@plugin_id)

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
      response = @aod.call(:get_pay_period_class_data, message: { 
        payPeriodClassNum: 1 })  
      @payperiods = response.body[:t_ae_pay_period_info]
      @prevstart = @payperiods[:prev_start].to_datetime
      @prevend   = @payperiods[:prev_end]  .to_datetime
      @currstart = @payperiods[:curr_start].to_datetime
      @currend   = @payperiods[:curr_end]  .to_datetime

      # Get the date range the user picked
      @begindate = Date.strptime(params[:begindate], "%m/%d/%Y")
      @enddate   = Date.strptime(params[:enddate],   "%m/%d/%Y")
      log 'payperiods', @payperiods
      log 'begindate', @begindate
      log 'enddate', @enddate
      log 'empids', empids

      # For each day in the date range, populate the lists
      @begindate.upto @enddate do |day|
        if @prevstart <= day && day <= @prevend
          prevdates << day
        elsif @currstart <= day && day <= @currend
          currdates << day
        end
      end

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
          # delete_edits 'drPrevPeriod', prevdates, empid
        end

        #----------------------------------
        # Delete edits in current period
        #----------------------------------

        # Progress("Deleting edits for employee id:  " + empid)
        if currdates.count > 0
          # delete_edits 'drCurrPeriod', currdates, empid
        end
      end

      a = session[:settings].justdeleteedits
      if a.nil? || a == false
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
        totals = get_last_punches totals, empids

        # log 'totals', totals

        #-------------------------------------------
        # Send new edits for these totals
        #-------------------------------------------

        # Progress("Sending edits")
        # send_edits totals
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
      response = @aod.call(:extract_employee_edits_by_idnum, message: {
        iDNum: empid,
        dateRangeEnum: payperiod,
        minDate: '',
        maxDate: '' })  
      @edits = response.body[:t_ae_edit].each
      @edits.each do |edit|
        # If the edit was made by this program, and was within these dates
        if edit[:reason_code_id] == session[:settings].reasoncode &&
           dates.include?(edit[:eff_date].to_datetime)
          # Delete it
          @aod.call(:delete_time_card_edit, message: edit)  
          deletions = true
        end
      end

      # Recompute this employee
      if deletions
        @aod.call(:recompute_employee_by_idnum, message: {
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

      ## THE FOLLOWING WAS RECEIVED FINE, BUT WOULDN'T RESPOND WITH ANY PAYLINES
      ## SO I MADE THE REQUEST MANUALLY (BELOW)

      # Send request, get response
      # response = @aod.call(:get_manually_selected_calculated_data, message: {
      #   aeExchangeStruct: {
      #     fieldSep: "{fs}",
      #     lineSep: "{ls}",
      #     rawData: 
      #       "daterange{fs}" + daterange + "{ls}" + 
      #       "calculation{fs}assaved{ls}" + 
      #       "noactivity{fs}skip{ls}" +
      #       "dataset{fs}daily{ls}" + 
      #       "Hyperquery{fs}All Employees" } })

      # Send request, get response
      response = @aod.call(:get_manually_selected_calculated_data, 
        xml: '<?xml version="1.0" encoding="UTF-8"?>
              <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" 
                xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" 
                xmlns:tns="http://tempuri.org/" 
                xmlns:types="http://tempuri.org/encodedTypes" 
                xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <soap:Body soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
                  <q1:getManuallySelectedCalculatedData 
                    xmlns:q1="urn:AeXMLBridgeIntf-IAeXMLBridge">
                    <AeExchangeStruct href="#id1" />
                  </q1:getManuallySelectedCalculatedData>
                  <q2:TAeExchangeStruct xmlns:q2="urn:AeXMLBridgeIntf" 
                    id="id1" xsi:type="q2:TAeExchangeStruct">
                    <RawData xsi:type="xsd:string">daterange{fs}' + daterange + '{ls}calculation{fs}assaved{ls}noactivity{fs}skip{ls}dataset{fs}daily{ls}hyperquery{fs}All Employees</RawData>
                    <LineSep xsi:type="xsd:string">{ls}</LineSep>
                    <FieldSep xsi:type="xsd:string">{fs}</FieldSep>
                    <ItemID xsi:type="xsd:int">0</ItemID>
                  </q2:TAeExchangeStruct>
                </soap:Body>
              </soap:Envelope>' )

      exch = response.body[:t_ae_exchange_struct]

      # Parse response
      paylines = parse_ae_exchange_struct(exch)

      # Filter out all emps that aren't transportation emps
      paylines = filter_pay_lines(paylines)

      paylines
    end

    def parse_ae_exchange_struct(ae_exch_struct)
      # Parse the RawData in ae_exch_struct into a list of pay lines

      paylines = []
      lines = ae_exch_struct[:raw_data].split('{ls}')
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
              emp_id:        p[0].to_s
              date:          p[1].to_datetime
              total_minutes: paylines.sum { |b| b[:hours_hund].to_f } } }
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
      response = @aod.call(
        :extract_ranged_transactions_using_hyper_query, message: {
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

        # Send edit to AoD
        edit = {
          reasoncodeid: session[:settings].reasoncode,
          empid:        total[:emp_id],
          edittype:     2,
          paydesid:     1,
          effdate:      total[:date].strftime('%Y-%m-%d'),
          efftime:      total[:last_punch].strftime('%Y-%m-%d'),
          hours:        roundAmt,
        }
        aod.call(:perform_time_card_edit, message: {
          aeEdit: edit,
          recomputeImmediately: true }) # true is important to recompute timecard
      end
    end
end
