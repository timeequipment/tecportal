class PluginServiceMasterController < ApplicationController
  before_filter :authenticate_user!
  around_filter :catch_exceptions
  layout "plugin_service_master"  

  @@plugin_id = 4

  def index
    log __method__

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

    # Create view model vars
    @team_filter            = session[:team_filter] || ""
    @cust_filter            = session[:cust_filter] || ""
    @startdate              = session[:settings].weekstart || Date.today.beginning_of_week
    @enddate                = @startdate + 6.days
    @export_all_customers   = session[:export_all_customers]
    @overwrite_scheds       = session[:overwrite_scheds]
    @apply_to_all_customers = session[:apply_to_all_customers]
    @apply_to_future        = session[:apply_to_future]

    log 'team_filter', @team_filter 
    log 'cust_filter', @cust_filter
    
    if session[:future_date].class == Date
      @future_date = session[:future_date].strftime "%m/%d/%Y"
    else
      @future_date = @enddate.strftime "%m/%d/%Y"
    end

    # Get teams
    @teams = PsvmEmp.where(active_status: 0).select(:custom1).uniq.map(&:custom1)
    @teams.delete(nil)  # Clean up nils
    @teams.delete("")   # Clean up blanks

    # Get customers and activities
    @customers = PsvmWorkgroup.where('wg_level = 3').order('wg_name')
    @activities = PsvmWorkgroup.where('wg_level = 5').order('wg_num')

    # Get employees
    @employees = get_filtered_emps(@team_filter, @cust_filter)

    # Make a view model
    @v = PluginServiceMaster::ViewModels::ViewWeekVM.new
    @v.start_date = @startdate
    @v.end_date = @enddate
    @v.emp_weeks = get_emp_weeks(@employees, @startdate, @enddate)
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
  end

  def get_employee
    log __method__
    employee = PsvmEmp.where(emp_id: params[:emp_id]).first
    workgroups = employee.psvm_workgroups.order('wg_name')
    render json: [ employee, workgroups ].to_json
  end

  def save_employee
    log __method__
    employee = PsvmEmp.where(emp_id: params[:emp_id]).first
    employee.first_name = params[:first_name]
    employee.last_name = params[:last_name]
    employee.custom1 = params[:custom1]
    employee.psvm_workgroups.clear
    employee.psvm_workgroup_ids = params[:psvm_workgroup_ids].to_a
    employee.save
    render json: true
  end

  def get_customer
    log __method__
    customer    = PsvmWorkgroup.where(wg_level: 3, wg_num: params[:wg_num]).first
    custpattern = PsvmCustPattern.where(wg_level: 3, wg_num: params[:wg_num]).first
    employees   = PsvmEmp
      .joins(:psvm_workgroups)
      .where(psvm_workgroups: {wg_level: 3, wg_num: params[:wg_num]})
      .order('last_name')
    render json: [ customer, custpattern, employees ].to_json
  end

  def save_customer
    log __method__
    customer = PsvmWorkgroup.where(wg_level: 3, wg_num: params[:wg_num]).first
    custpattern = PsvmCustPattern.where(wg_level: 3, wg_num: params[:wg_num]).first_or_initialize
    customer.wg_name = params[:wg_name]
    custpattern.day1 = params[:day_field1]
    custpattern.day2 = params[:day_field2]
    custpattern.day3 = params[:day_field3]
    custpattern.day4 = params[:day_field4]
    custpattern.day5 = params[:day_field5]
    custpattern.day6 = params[:day_field6]
    custpattern.day7 = params[:day_field7]
    custpattern.save
    customer.save
    render json: true
  end

  def import_employees
    log __method__
    cache_save current_user.id, 'svm_import_status', 'Initializing'
    cache_save current_user.id, 'svm_import_progress', '10'
    sleep 1

    # Request employees from AoD, in the background
    Delayed::Job.enqueue PluginServiceMaster::ImportEmployees.new(
      current_user.id,
      session[:settings])
    
    render json: true
  end

  def import_workgroups
    log __method__
    cache_save current_user.id, 'svm_import_status', 'Initializing'
    cache_save current_user.id, 'svm_import_progress', '10'
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

    # Get the dates for the week we're exporting
    start_date = session[:settings].weekstart
    end_date = start_date + 6.days

    # Get the options
    session[:export_all_customers] = params[:export_all_customers].to_bool

    # Get the employees we're exporting scheds for
    if session[:export_all_customers] == true
      employees = get_filtered_emps(nil, nil)
    else
      employees = get_filtered_emps(session[:team_filter], 
                                    session[:cust_filter])
    end

    log 'employees count', employees.count

    # Get the schedules to export
    scheds = []
    v = PluginServiceMaster::ViewModels::ViewWeekVM.new
    v.start_date = start_date
    v.end_date = end_date
    v.emp_weeks = get_emp_weeks(employees, start_date, end_date)

    # For each empweek
    v.emp_weeks.each do |ew|

      # For each custweek
      ew.cust_weeks.each do |cw|

        # Get the scheds
        scheds << cw.day1 if cw.day1.id.present?
        scheds << cw.day2 if cw.day2.id.present?
        scheds << cw.day3 if cw.day3.id.present?
        scheds << cw.day4 if cw.day4.id.present?
        scheds << cw.day5 if cw.day5.id.present?
        scheds << cw.day6 if cw.day6.id.present?
      end
    end

    log 'export count', scheds.count

    # Export them to AoD
    if scheds.count > 0
      cache_save current_user.id, 'svm_export_scheds_status', 'Initializing'
      cache_save current_user.id, 'svm_export_scheds_progress', '10'
      sleep 1

      Delayed::Job.enqueue PluginServiceMaster::ExportToAod.new(
        current_user.id,
        session[:settings],
        scheds)
    end

    render json: true
  end

  def generate_scheds
    log __method__

    # Get the dates for the week we're viewing
    start_date = session[:settings].weekstart
    end_date = start_date + 6.days

    # Get the options
    session[:overwrite_scheds]       = params[:overwrite_scheds].to_bool
    session[:apply_to_all_customers] = params[:apply_to_all_customers].to_bool
    session[:apply_to_future]        = params[:apply_to_future].to_bool
    session[:future_date]            = 
      Date.strptime(params[:future_date], "%m/%d/%Y") rescue end_date

    # Get the employees we're generating scheds for
    if session[:apply_to_all_customers] == true
      employees = get_filtered_emps(nil, nil)
    else
      employees = get_filtered_emps(session[:team_filter], 
                                    session[:cust_filter])
    end

    if session[:apply_to_future] == true &&
       session[:future_date] > end_date
      future_date = session[:future_date]
    else
      future_date = end_date
    end

    while start_date <= future_date
      # Get the current view
      v = PluginServiceMaster::ViewModels::ViewWeekVM.new
      v.start_date = start_date
      v.end_date = end_date
      v.emp_weeks = get_emp_weeks(employees, start_date, end_date)

      # For each empweek
      v.emp_weeks.each do |ew|

        # For each custweek
        ew.cust_weeks.each do |cw|

          # If the customer has a pattern
          pattern = cw.customer.pattern
          if pattern.present?

            # For each day that is unscheduled, get it from the pattern
            filekey = ew.employee.filekey
            custnum = cw.customer.wg_num
            if (session[:overwrite_scheds] == true || cw.day1.id.nil?) && 
                start_date + 0.days <= future_date && pattern.day1.present?
                  cw.day1 = convert_to_sched(filekey, custnum, start_date + 0.days, pattern.day1, session[:overwrite_scheds])
            end
            if (session[:overwrite_scheds] == true || cw.day2.id.nil?) && 
                start_date + 1.days <= future_date && pattern.day2.present?
                  cw.day2 = convert_to_sched(filekey, custnum, start_date + 1.days, pattern.day2, session[:overwrite_scheds])
            end
            if (session[:overwrite_scheds] == true || cw.day3.id.nil?) && 
                start_date + 2.days <= future_date && pattern.day3.present?
                  cw.day3 = convert_to_sched(filekey, custnum, start_date + 2.days, pattern.day3, session[:overwrite_scheds])
            end
            if (session[:overwrite_scheds] == true || cw.day4.id.nil?) && 
                start_date + 3.days <= future_date && pattern.day4.present?
                  cw.day4 = convert_to_sched(filekey, custnum, start_date + 3.days, pattern.day4, session[:overwrite_scheds])
            end
            if (session[:overwrite_scheds] == true || cw.day5.id.nil?) && 
                start_date + 4.days <= future_date && pattern.day5.present?
                  cw.day5 = convert_to_sched(filekey, custnum, start_date + 4.days, pattern.day5, session[:overwrite_scheds])
            end
            if (session[:overwrite_scheds] == true || cw.day6.id.nil?) && 
                start_date + 5.days <= future_date && pattern.day6.present?
                  cw.day6 = convert_to_sched(filekey, custnum, start_date + 5.days, pattern.day6, session[:overwrite_scheds])
            end
          end
        end
      end

      start_date += 7.days
      end_date += 7.days
    end

    redirect_to action: 'index' 
  end

  def progress

    log __method__
    progress = cache_get current_user.id, 'svm_' + params[:progress_type] + '_progress'
    status   = cache_get current_user.id, 'svm_' + params[:progress_type] + '_status'

    if progress != '100'
      render json: { progress: progress, status: status }.to_json
    else
      render json: true
    end
  end

  private

  def get_filtered_emps(team_filter, cust_filter)
    log __method__
    employees = []

    # If we're filtering by customer only, get the employees just for this customer
    if team_filter.blank? && cust_filter.present?
      employees = PsvmEmp
        .joins(:psvm_workgroups)
        .where(psvm_workgroups: {wg_level: 3, wg_num: cust_filter})
        .order('last_name')

    # If we're filtering by team only, get the employees just for this team
    elsif team_filter.present? && cust_filter.blank?
      employees = PsvmEmp
        .joins(:psvm_workgroups)
        .where(custom1: team_filter)
        .order('last_name')

    # If we're filtering by both, get the employees matching both
    elsif team_filter.present? && cust_filter.present?
      employees = PsvmEmp
        .joins(:psvm_workgroups)
        .where(custom1: team_filter, 
               psvm_workgroups: {wg_level: 3, wg_num: cust_filter})
        .order('last_name')    

    # If we're not filtering, get all employees
    elsif team_filter.nil? && cust_filter.nil?
      employees = PsvmEmp.all
    end

    employees
  end

  def get_emp_weeks employees, start_date, end_date
    log __method__
    emp_weeks = []

    # For each employee
    employees.each do |emp|
      # Make an empweek
      ew = PluginServiceMaster::ViewModels::EmpWeekVM.new
      ew.employee = emp
      ew.cust_weeks = get_cust_weeks(emp, start_date, end_date)

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

  def get_cust_weeks employee, start_date, end_date
    log __method__
    cust_weeks = []

    # Get the customers this employee is assigned to
    assigned_custs = employee.customers.map {|c| c.wg_num }

    # Get the customers this employee is scheduled for
    scheduled_custs = PsvmSched.where(sch_date: start_date..end_date, filekey: employee.filekey)
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
        sch_date: start_date..end_date, 
        filekey: employee.filekey, 
        sch_wg3: custnum)
        .order('sch_date, sch_start_time')

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
          sch_date: start_date + 0.days, 
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc, 
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      end
      if cw.day2.nil? 
        cw.day2 = PsvmSched.new({
          filekey:  employee.filekey, 
          sch_wg3:  custnum, 
          sch_date: start_date + 1.days, 
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc, 
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      end
      if cw.day3.nil?
        cw.day3 = PsvmSched.new({
          filekey:  employee.filekey, 
          sch_wg3:  custnum, 
          sch_date: start_date + 2.days, 
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc, 
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      end
      if cw.day4.nil?
        cw.day4 = PsvmSched.new({
          filekey:  employee.filekey, 
          sch_wg3:  custnum, 
          sch_date: start_date + 3.days, 
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc, 
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      end
      if cw.day5.nil?
        cw.day5 = PsvmSched.new({
          filekey:  employee.filekey, 
          sch_wg3:  custnum, 
          sch_date: start_date + 4.days, 
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc, 
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      end
      if cw.day6.nil?
        cw.day6 = PsvmSched.new({
          filekey:  employee.filekey, 
          sch_wg3:  custnum, 
          sch_date: start_date + 5.days, 
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc, 
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      end
      
      cust_weeks << cw
    end

    cust_weeks
  end

  def convert_to_sched(filekey, custnum, date, serialized, overwrite)
    log __method__

    s = JSON[serialized]

    s_start = Time.parse(s["start_time"])
    s_end = Time.parse(s["end_time"])
    sch_hours_hund = s["hours"].to_f
    sch_wg5 = s["activity"].to_i

    # If we're overwriting schedules
    if overwrite == true
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

  def catch_exceptions
    yield
  rescue Exception => exc
    log 'exception', exc.message
    log 'exception backtrace', exc.backtrace
    flash.now[:alert] = exc.message
  end

end
