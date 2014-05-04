class PluginServiceMasterController < ApplicationController
  before_filter :authenticate_user!
  around_filter :catch_exceptions
  layout "plugin_service_master"  

  @@plugin_id = 4

  def index
    log __method__
    log 'overwrite_scheds 1', session[:overwrite_scheds]
    log 'apply_to_all_customers 1', session[:apply_to_all_customers]
    log 'apply_to_future 1', session[:apply_to_future]
    log 'future_date 1', session[:future_date]

    # Get plugin settings for this user
    cls = PluginServiceMaster::Settings
    if session[:settings].class != cls
       session[:settings] = 
         get_settings(cls, 
          current_user.id, 
          current_user.customer_id, 
          @@plugin_id)
    end

    # Get the dates for the week we're viewing
    session[:startdate] = session[:settings].weekstart || Date.today.beginning_of_week
    session[:enddate] = session[:startdate] + 6.days

    # Create view model
    construct_view
  end

  def settings
    log __method__
  end

  def save_settings
    log __method__
  end

  def employee_list
    log __method__
    @employees = PsvmEmp.where(active_status: 0).order('last_name, first_name')
  end

  def customer_list
    log __method__
    @customers = PsvmWorkgroup.where('wg_level = 3').order('wg_name')
    @activities = PsvmWorkgroup.where('wg_level = 5').select('wg_num, wg_name').order('wg_name')
    # if params[:wg_num]
    #   @customer    = PsvmWorkgroup.where(wg_level: 3, wg_num: params[:wg_num]).first
    #   @custpattern = PsvmCustPattern.where(wg_level: 3, wg_num: params[:wg_num]).first
    #   @customer    ||= PsvmWorkgroup.new
    #   @custpattern ||= PsvmCustPattern.new
    # end
  end

  def get_employee
    log __method__
    employee = PsvmEmp.where(emp_id: params[:emp_id]).first
    workgroups = employee.psvm_workgroups.order('wg_name')
    render json: [ employee, workgroups ].to_json
  end

  def save_employee
    log __method__
    @employee = PsvmEmp.where(emp_id: params[:emp_id]).first
    @employee.first_name = params[:first_name]
    @employee.last_name = params[:last_name]
    @employee.custom1 = params[:custom1]
    @employee.psvm_workgroups.clear
    @employee.psvm_workgroup_ids = params[:psvm_workgroup_ids].to_a
    @employee.save
    render json: true
  end

  def get_customer
    log __method__
    @customer      = PsvmWorkgroup.where(wg_level: 3, wg_num: params[:wg_num]).first
    @custpattern = PsvmCustPattern.where(wg_level: 3, wg_num: params[:wg_num]).first
    render json: [ @customer, @custpattern, @activities ].to_json
  end

  def save_customer
    log __method__
    @customer = PsvmWorkgroup.where(wg_level: 3, wg_num: params[:wg_num]).first
    @custpattern = PsvmCustPattern.where(wg_level: 3, wg_num: params[:wg_num]).first_or_initialize
    @customer.wg_name = params[:wg_name]
    @custpattern.day1 = params[:day_field1]
    @custpattern.day2 = params[:day_field2]
    @custpattern.day3 = params[:day_field3]
    @custpattern.day4 = params[:day_field4]
    @custpattern.day5 = params[:day_field5]
    @custpattern.day6 = params[:day_field6]
    @custpattern.day7 = params[:day_field7]
    @custpattern.save
    @customer.save
    render json: true
  end

  def import_employees
    log __method__
    cache_save current_user.id, 'svm_status', 'Initializing'
    cache_save current_user.id, 'svm_progress', '10'
    sleep 1

    # Request employees from AoD, in the background
    Delayed::Job.enqueue PluginServiceMaster::ImportEmployees.new(
      current_user.id,
      session[:settings])
    
    render json: true
  end

  def import_workgroups
    log __method__
    cache_save current_user.id, 'svm_status', 'Initializing'
    cache_save current_user.id, 'svm_progress', '10'
    sleep 1

    # Request workgroup3 from AoD, in the background
    Delayed::Job.enqueue PluginServiceMaster::ImportWorkgroups.new(
      current_user.id,
      session[:settings],
      3)

    # Request workgroup5 from AoD, in the background
    Delayed::Job.enqueue PluginServiceMaster::ImportWorkgroups.new(
      current_user.id,
      session[:settings],
      5)

    render json: true
  end

  def save_schedule
    log __method__
    schid = params[:schid]
    filekey = params[:filekey]
    sch_date = params[:sch_date]
    sch_start_time = params[:sch_start_time]
    sch_end_time = params[:sch_end_time]
    sch_wg3 = params[:sch_wg3]
    sch_wg5 = params[:sch_wg5]

    s = PsvmSched.where(id: schid).first_or_initialize
    s.filekey = filekey if filekey.present?
    s.sch_date = Date.parse(sch_date) if sch_date.present?
    s.sch_start_time = DateTime.parse(sch_start_time).utc if sch_start_time.present?
    s.sch_end_time = DateTime.parse(sch_end_time).utc if sch_end_time.present?
    s.sch_wg3 = sch_wg3 if sch_wg3.present?
    s.sch_wg5 = sch_wg5 if sch_wg5.present?
    if s.sch_end_time < s.sch_start_time 
      s.sch_end_time = s.sch_end_time + 1.days
    end
    s.sch_hours_hund = (s.sch_end_time - s.sch_start_time) / 3600
    s.save

    render json: true
  end

  def delete_schedule
    log __method__
    PsvmSched.destroy(params[:schid].to_i) if params[:schid].present?

    render json: true
  end

  def team_filter
    log __method__
    # Save the filter to the session
    session[:team_filter] = params[:team_filter]
    render json: true
  end

  def cust_filter
    log __method__
    # Save the filter to the session
    session[:cust_filter] = params[:cust_filter]
    render json: true
  end

  def next_week
    log __method__
    session[:settings].weekstart = session[:settings].weekstart + 7.days
    redirect_to action: 'index' 
  end

  def prev_week
    log __method__
    session[:settings].weekstart = session[:settings].weekstart - 7.days
    redirect_to action: 'index' 
  end

  def export_scheds
    log __method__
    cache_save current_user.id, 'svm_status', 'Initializing'
    cache_save current_user.id, 'svm_progress', '10'
    sleep 1

    # Get the schedules to export
    scheds = session[:scheds_to_export] || []
    log 'export count', scheds.count

    # Export them to AoD
    if scheds.length > 0
      Delayed::Job.enqueue PluginServiceMaster::ExportToAod.new(
        current_user.id,
        session[:settings],
        scheds)
    end

    render json: true
  end

  def generate_scheds
    log __method__

    # Get the options
    session[:overwrite_scheds]       = params[:overwrite_scheds]
    session[:apply_to_all_customers] = params[:apply_to_all_customers]
    session[:apply_to_future]        = params[:apply_to_future]
    session[:future_date]            = params[:future_date]

    # Get this view
    construct_view

    # For each empweek
    @v.emp_weeks.each do |ew|

      # For each custweek
      ew.cust_weeks.each do |cw|

        # If the customer has a pattern
        pattern = cw.customer.pattern
        if pattern.present?

          # For each day that is unscheduled, get it from the pattern
          filekey = ew.employee.filekey
          custnum = cw.customer.wg_num
          if (session[:overwrite_scheds] == "1" || cw.day1.id.nil?) && pattern.day1.present?
            cw.day1 = convert_to_sched(filekey, custnum, @startdate + 0.days, pattern.day1)
          end
          if (session[:overwrite_scheds] == "1" || cw.day2.id.nil?) && pattern.day2.present?
            cw.day2 = convert_to_sched(filekey, custnum, @startdate + 1.days, pattern.day2)
          end
          if (session[:overwrite_scheds] == "1" || cw.day3.id.nil?) && pattern.day3.present?
            cw.day3 = convert_to_sched(filekey, custnum, @startdate + 2.days, pattern.day3)
          end
          if (session[:overwrite_scheds] == "1" || cw.day4.id.nil?) && pattern.day4.present?
            cw.day4 = convert_to_sched(filekey, custnum, @startdate + 3.days, pattern.day4)
          end
          if (session[:overwrite_scheds] == "1" || cw.day5.id.nil?) && pattern.day5.present?
            cw.day5 = convert_to_sched(filekey, custnum, @startdate + 4.days, pattern.day5)
          end
          if (session[:overwrite_scheds] == "1" || cw.day6.id.nil?) && pattern.day6.present?
            cw.day6 = convert_to_sched(filekey, custnum, @startdate + 5.days, pattern.day6)
          end
        end
      end
    end

    redirect_to action: 'index' 
  end

  def progress
    log __method__
    progress = cache_get current_user.id, 'svm_progress'
    status   = cache_get current_user.id, 'svm_status'

    if progress != '100'
      render json: { progress: progress, status: status }.to_json
    else
      render json: true
    end
  end


  private

  def construct_view
    log __method__

    # Init vars
    @team_filter            = session[:team_filter]
    @cust_filter            = session[:cust_filter]
    @startdate              = session[:startdate]
    @enddate                = session[:enddate]
    @overwrite_scheds       = session[:overwrite_scheds]
    @apply_to_all_customers = session[:apply_to_all_customers]
    @apply_to_future        = session[:apply_to_future]
    @future_date            = session[:future_date]

    # Get teams
    @teams = PsvmEmp.where(active_status: 0).select(:custom1).uniq.map(&:custom1)
    @teams.delete(nil)
    @teams.delete("")

    # Get customers and activities
    @customers = PsvmWorkgroup.where('wg_level = 3').order('wg_name')
    @activities = PsvmWorkgroup.where('wg_level = 5').order('wg_num')

    # If we're filtering by customer only, get the employees just for this customer
    @employees = []
    if @team_filter.blank? && @cust_filter.present?
      @employees = PsvmEmp
      .joins(:psvm_workgroups)
      .where(psvm_workgroups: {wg_level: 3, wg_num: @cust_filter})
      .order('last_name')

    # If we're filtering by team only, get the employees just for this team
    elsif @team_filter.present? && @cust_filter.blank?
      @employees = PsvmEmp
      .joins(:psvm_workgroups)
      .where(custom1: @team_filter)
      .order('last_name')

    # If we're filtering by both, get the employees matching both
    elsif @team_filter.present? && @cust_filter.present?
      @employees = PsvmEmp
      .joins(:psvm_workgroups)
      .where(custom1: @team_filter, 
             psvm_workgroups: {wg_level: 3, wg_num: @cust_filter})
      .order('last_name')    
    end

    # Clear the list of schedules we can export
    clear_scheds_to_export

    # Make a view viewmodel
    @v = PluginServiceMaster::ViewModels::ViewWeekVM.new
    @v.start_date = @startdate
    @v.end_date = @enddate
    @v.emp_weeks = get_emp_weeks(@employees, @startdate, @enddate)

  end

  def get_emp_weeks employees, startdate, enddate
    log __method__
    emp_weeks = []

    # For each employee
    employees.each do |emp|
      # Make an empweek
      ew = PluginServiceMaster::ViewModels::EmpWeekVM.new
      ew.employee = emp
      ew.cust_weeks = get_cust_weeks(emp, startdate, enddate)

      # Check for any overlapping schedules
      ew.cust_weeks.each do |cw1|
        ew.cust_weeks.each do |cw2|
          if cw1.day1.id != cw2.day1.id && 
             cw1.day1.sch_start_time < cw2.day1.sch_end_time &&
             cw2.day1.sch_start_time < cw1.day1.sch_end_time
             cw1.day1.overlapping = true;
             cw2.day1.overlapping = true;
          end
          if cw1.day2.id != cw2.day2.id && 
             cw1.day2.sch_start_time < cw2.day2.sch_end_time &&
             cw2.day2.sch_start_time < cw1.day2.sch_end_time
             cw1.day2.overlapping = true;
             cw2.day2.overlapping = true;
          end
          if cw1.day3.id != cw2.day3.id && 
             cw1.day3.sch_start_time < cw2.day3.sch_end_time &&
             cw2.day3.sch_start_time < cw1.day3.sch_end_time
             cw1.day3.overlapping = true;
             cw2.day3.overlapping = true;
          end
          if cw1.day4.id != cw2.day4.id && 
             cw1.day4.sch_start_time < cw2.day4.sch_end_time &&
             cw2.day4.sch_start_time < cw1.day4.sch_end_time
             cw1.day4.overlapping = true;
             cw2.day4.overlapping = true;
          end
          if cw1.day5.id != cw2.day5.id && 
             cw1.day5.sch_start_time < cw2.day5.sch_end_time &&
             cw2.day5.sch_start_time < cw1.day5.sch_end_time
             cw1.day5.overlapping = true;
             cw2.day5.overlapping = true;
          end
          if cw1.day6.id != cw2.day6.id && 
             cw1.day6.sch_start_time < cw2.day6.sch_end_time &&
             cw2.day6.sch_start_time < cw1.day6.sch_end_time
             cw1.day6.overlapping = true;
             cw2.day6.overlapping = true;
          end
        end  
      end

      # Calculate total hours
      ew.total_hours = 0.0
      ew.cust_weeks.each do |cw|
        ew.total_hours += cw.total_hours
      end

      # If total hours > 29, print exception
      ew.exceptions = 'Over limit!' if ew.total_hours >= 29.0

      # Save empweek
      emp_weeks << ew
    end

    emp_weeks
  end

  def get_cust_weeks employee, startdate, enddate
    log __method__
    cust_weeks = []

    # Get the customers this employee is assigned to
    assigned_custs = employee.customers.map {|c| c.wg_num }

    # Get the customers this employee is scheduled for
    scheduled_custs = PsvmSched.where(sch_date: @startdate..@enddate, filekey: employee.filekey)
      .select(:sch_wg3)
      .group(:sch_wg3)
      .map &:sch_wg3

    # Merge both together
    all_custs = assigned_custs + scheduled_custs

    # Eliminate duplicates
    all_custs = all_custs.uniq

    # For each customer
    all_custs.each do |custnum|

      # Make a custweek
      cw = PluginServiceMaster::ViewModels::CustWeekVM.new
      cw.customer = PsvmWorkgroup.where(wg_level: 3, wg_num: custnum).first
      cw.total_hours = 0

      # Get schedules for this employee/customer
      scheds = PsvmSched.where(
        sch_date: @startdate..@enddate, 
        filekey: employee.filekey, 
        sch_wg3: custnum)
        .order('sch_date, sch_start_time')

      # Save these schedules in case we want to export them to AoD later
      save_scheds_to_export scheds

      # For each sched
      scheds.each do |sched|
        # Plug it into a day on the custweek
        cw.day1 = sched if sched.sch_date.monday?
        cw.day2 = sched if sched.sch_date.tuesday?
        cw.day3 = sched if sched.sch_date.wednesday?
        cw.day4 = sched if sched.sch_date.thursday?
        cw.day5 = sched if sched.sch_date.friday?
        cw.day6 = sched if sched.sch_date.saturday?

        # Tally hours
        cw.total_hours += sched.sch_hours_hund
      end

      # Create default scheds on days that didn't have them   
      if cw.day1.nil?
        cw.day1 = PsvmSched.new({
          filekey:  employee.filekey, 
          sch_wg3:  custnum, 
          sch_date: @startdate + 0.days, 
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc, 
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      end
      if cw.day2.nil? 
        cw.day2 = PsvmSched.new({
          filekey:  employee.filekey, 
          sch_wg3:  custnum, 
          sch_date: @startdate + 1.days, 
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc, 
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      end
      if cw.day3.nil?
        cw.day3 = PsvmSched.new({
          filekey:  employee.filekey, 
          sch_wg3:  custnum, 
          sch_date: @startdate + 2.days, 
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc, 
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      end
      if cw.day4.nil?
        cw.day4 = PsvmSched.new({
          filekey:  employee.filekey, 
          sch_wg3:  custnum, 
          sch_date: @startdate + 3.days, 
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc, 
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      end
      if cw.day5.nil?
        cw.day5 = PsvmSched.new({
          filekey:  employee.filekey, 
          sch_wg3:  custnum, 
          sch_date: @startdate + 4.days, 
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc, 
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      end
      if cw.day6.nil?
        cw.day6 = PsvmSched.new({
          filekey:  employee.filekey, 
          sch_wg3:  custnum, 
          sch_date: @startdate + 5.days, 
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc, 
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      end
      
      cust_weeks << cw
    end

    cust_weeks
  end

  def convert_to_sched(filekey, custnum, date, serialized)
    log __method__

    s = JSON[serialized]

    s_start = Time.parse(s["start_time"])
    s_end = Time.parse(s["end_time"])
    sch_hours_hund = s["hours"].to_f
    sch_wg5 = s["activity"].to_i

    # If we're overwriting schedules
    if @overwrite_scheds == "1"
      # Get any schedules on this day
      old_scheds = PsvmSched.where(filekey: filekey, sch_date: date)
      old_scheds.each do |o|
        o.destroy
      end
    end

    sched = PsvmSched.new
    sched.sch_date = date
    sched.filekey = filekey
    sched.sch_wg3 = custnum
    sched.sch_start_time = DateTime.new(
      date.year, date.month, date.day, s_start.hour, s_start.min)
    sched.sch_end_time = DateTime.new(
      date.year, date.month, date.day, s_end.hour, s_end.min)

    sched.sch_hours_hund = sch_hours_hund
    sched.sch_wg5 = sch_wg5
    sched.save

    sched
  end

  def save_scheds_to_export(scheds)
    log __method__
    saved_scheds = session[:scheds_to_export] || []
    saved_scheds.concat scheds
    session[:scheds_to_export] = saved_scheds
  end

  def clear_scheds_to_export
    log __method__
    session[:scheds_to_export] = []
  end

  def log_method
    log __method__
  end

  def catch_exceptions
    yield
  rescue Exception => exc
    log 'exception', exc.message
    log 'exception backtrace', exc.backtrace
    flash.now[:alert] = exc.message
  end

end
