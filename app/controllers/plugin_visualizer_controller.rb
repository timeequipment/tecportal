class PluginVisualizerController < ApplicationController
  before_filter :authenticate_user!

  account = ""
  username = ""
  password = ""

  # Get User Settings

  # Get Customer Settings

  # Create interface to AoD
  @@aod = PluginsHelper::AodInterface.new(account, username, password)

  def index
    # Get pay periods from AoD
    response = @@aod.get_pay_period_class_data(message: { 
      payPeriodClassNum: 1 })  
    @payperiods = response.body[:t_ae_pay_period_info]
    @prevstart = @payperiods[:prev_start].to_datetime.strftime('%-m-%d-%Y')
    @prevend = @payperiods[:prev_end].to_datetime.strftime('%-m-%d-%Y')
    @currstart = @payperiods[:curr_start].to_datetime.strftime('%-m-%d-%Y')
    @currend = @payperiods[:curr_end].to_datetime.strftime('%-m-%d-%Y')
  end

  def settings
  end

  def create_report
    # Get pay period chosen
    if params[:payperiod] == "0"
      date_range = "drPrevPeriod" 
    else
      date_range = "drCurrPeriod" 
    end

    # # Get hyperqueries from AoD
    # response = @@aod.get_hyper_queries_simple()
    # @hyperqueries = response.body[:get_hyper_queries_simple_response][:return][:item]

    # Get schedules from AoD
    response = @@aod.extract_ranged_schedules_using_hyper_query(message: { 
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
      s.intime = (schedule[:sch_date].to_s + " " + schedule[:sch_start_time].to_s).to_datetime
      s.outtime = (schedule[:sch_date].to_s + " " + schedule[:sch_end_time].to_s).to_datetime
      s.hours = schedule[:sch_hours_hund]
      s.earningscode = ""
      s.lunchplan = ""
      s.prepaiddate = ""
      s.workedflag = "TRUE"
      s.scheduletype = "Recurring"
      s.timezone = "PST"  

      # Offset 1 day for 3rd shifters whose end time would be numerically less than their start time
      if s.outtime <= s.intime
        s.outtime = s.outtime + 1
      end

      # If this is a benefit or planned absence schedule
      if schedule[:sch_type] == "steAbsPlnBen" || schedule[:sch_type] == "steAbsPlnPayDes"
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
    session[:schedfile] = @schedheader + "\n" + @schedrecords.join("\n")
  end

  def download_report
    send_data session[:schedfile].to_s, :filename => "schedules.csv", :type => "text/plain" 
  end
end
