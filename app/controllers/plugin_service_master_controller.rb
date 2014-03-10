class PluginServiceMasterController < ApplicationController
  before_filter :authenticate_user!
  layout "plugin_service_master"  

  @@plugin_id = 4

  def index
    begin
      log "\n\nmethod", 'index', 0

      construct_view

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def construct_view

    # Get plugin settings for this user
    session[:settings] ||= get_settings(PluginServiceMaster::Settings, 
      current_user.id, 
      current_user.customer_id, 
      @@plugin_id)

    # Get the dates for the week we're viewing
    @startdate = session[:settings].weekstart
    @startdate ||= Date.today.beginning_of_week
    @enddate = @startdate + 6.days

    # Get customers and activities
    @customers = PsvmWorkgroup.where('wg_level = 3').order('wg_name')
    @activities = PsvmWorkgroup.where('wg_level = 5').order('wg_num')

    # Get the current customer filter
    @cust_filter = session[:cust_filter]
    @cust_filter ||= PsvmWorkgroup.where(wg_level: 3).first

    # Get active employees that are assigned to this customer
    @employees = PsvmEmp.where(wg3: @cust_filter, active_status: 0).order('last_name')

    # Make a view week
    @v = PluginServiceMaster::ViewWeek.new
    @v.start_date = @startdate
    @v.end_date = @enddate
    @v.emp_weeks = get_emp_weeks(@employees, @startdate, @enddate)

    @v
  end

  def get_emp_weeks employees, startdate, enddate
    emp_weeks = []

    # For each employee
    employees.each do |emp|
      # Make an empweek
      ew = PluginServiceMaster::EmpWeek.new
      ew.employee = emp
      ew.cust_weeks = get_cust_weeks(emp, startdate, enddate)

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
    cust_weeks = []

    # Get the customers this employee is assigned to
    assigned_custs = employee.customers.map {|c| c.wg_num }

    # And the home customer
    assigned_custs << employee.wg3

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
      cw = PluginServiceMaster::CustWeek.new
      cw.customer = PsvmWorkgroup.where(wg_level: 3, wg_num: custnum).first
      cw.total_hours = 0

      # Get schedules for this employee/customer
      scheds = PsvmSched.where(
        sch_date: @startdate..@enddate, 
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
          sch_date: @startdate + 0.days, 
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0), 
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0)})
      end
      if cw.day2.nil? 
        cw.day2 = PsvmSched.new({
          filekey:  employee.filekey, 
          sch_wg3:  custnum, 
          sch_date: @startdate + 1.days, 
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0), 
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0)})
      end
      if cw.day3.nil?
        cw.day3 = PsvmSched.new({
          filekey:  employee.filekey, 
          sch_wg3:  custnum, 
          sch_date: @startdate + 2.days, 
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0), 
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0)})
      end
      if cw.day4.nil?
        cw.day4 = PsvmSched.new({
          filekey:  employee.filekey, 
          sch_wg3:  custnum, 
          sch_date: @startdate + 3.days, 
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0), 
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0)})
      end
      if cw.day5.nil?
        cw.day5 = PsvmSched.new({
          filekey:  employee.filekey, 
          sch_wg3:  custnum, 
          sch_date: @startdate + 4.days, 
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0), 
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0)})
      end
      if cw.day6.nil?
        cw.day6 = PsvmSched.new({
          filekey:  employee.filekey, 
          sch_wg3:  custnum, 
          sch_date: @startdate + 5.days, 
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0), 
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0)})
      end
      
      cust_weeks << cw
    end

    cust_weeks
  end

  def settings
    begin
      log "\n\nmethod", 'settings', 0
    
    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def get_employee
    begin
      log "\n\nmethod", 'get_employee', 0
      @employee = PsvmEmp.where(emp_id: params[:emp_id]).first
      @workgroups = @employee.psvm_workgroups.order('wg_name')
      render json: [ @employee, @workgroups ].to_json
      
    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def get_customer
    begin
      log "\n\nmethod", 'get_customer', 0
      @customer      = PsvmWorkgroup.where(wg_level: 3, wg_num: params[:wg_num]).first
      @custpattern = PsvmCustPattern.where(wg_level: 3, wg_num: params[:wg_num]).first
      render json: [ @customer, @custpattern, @activities ].to_json
    
    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def save_customer
    begin
      log "\n\nmethod", 'save_customer', 0
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
    
    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def save_employee
    begin
      log "\n\nmethod", 'save_employee', 0
      @employee = PsvmEmp.where(emp_id: params[:emp_id]).first
      @employee.first_name = params[:first_name]
      @employee.last_name = params[:last_name]
      @employee.psvm_workgroups.clear
      @employee.psvm_workgroup_ids = params[:psvm_workgroup_ids].to_a
      @employee.save
      render json: true
    
    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def employee_list
    begin
      log "\n\nmethod", 'employee_list', 0
      @employees = PsvmEmp.where(active_status: 0).order('last_name, first_name')

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def customer_list
    begin
      log "\n\nmethod", 'customer_list', 0
      @customers = PsvmWorkgroup.where('wg_level = 3').order('wg_name')
      @activities = PsvmWorkgroup.where('wg_level = 5').select('wg_num, wg_name').order('wg_name')
      if params[:wg_num]
        @customer    = PsvmWorkgroup.where(wg_level: 3, wg_num: params[:wg_num]).first
        @custpattern = PsvmCustPattern.where(wg_level: 3, wg_num: params[:wg_num]).first
        @customer    ||= PsvmWorkgroup.new
        @custpattern ||= PsvmCustPattern.new
      end
  
    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def import_employees
    begin
      log "\n\nmethod", 'import_employees', 0
      
      # Request employees from AoD, in the background
      Delayed::Job.enqueue PluginServiceMaster::ImportEmployees.new(
        current_user.id,
        session[:settings])
      render json: true

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def import_workgroups
    begin
      log "\n\nmethod", 'import_workgroups', 0
      
      # # Request workgroup1 from AoD, in the background
      # Delayed::Job.enqueue PluginServiceMaster::ImportWorkgroups.new(
      #   current_user.id,
      #   session[:settings],
      #   1)

      # # Request workgroup2 from AoD, in the background
      # Delayed::Job.enqueue PluginServiceMaster::ImportWorkgroups.new(
      #   current_user.id,
      #   session[:settings],
      #   2)

      # Request workgroup3 from AoD, in the background
      Delayed::Job.enqueue PluginServiceMaster::ImportWorkgroups.new(
        current_user.id,
        session[:settings],
        3)

      # # Request workgroup4 from AoD, in the background
      # Delayed::Job.enqueue PluginServiceMaster::ImportWorkgroups.new(
      #   current_user.id,
      #   session[:settings],
      #   4)

      # Request workgroup5 from AoD, in the background
      Delayed::Job.enqueue PluginServiceMaster::ImportWorkgroups.new(
        current_user.id,
        session[:settings],
        5)

      # # Request workgroup6 from AoD, in the background
      # Delayed::Job.enqueue PluginServiceMaster::ImportWorkgroups.new(
      #   current_user.id,
      #   session[:settings],
      #   6)

      render json: true

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def load_schedules
    begin
      log "\n\nmethod", 'load_schedules', 0

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def save_schedule
    begin
      log "\n\nmethod", 'save_schedule', 0
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
      s.sch_start_time = DateTime.parse(sch_start_time) if sch_start_time.present?
      s.sch_end_time = DateTime.parse(sch_end_time) if sch_end_time.present?
      s.sch_wg3 = sch_wg3 if sch_wg3.present?
      s.sch_wg5 = sch_wg5 if sch_wg5.present?
      if s.sch_end_time < s.sch_start_time 
        s.sch_end_time = s.sch_end_time + 1.days
      end
      s.sch_hours_hund = (s.sch_end_time - s.sch_start_time) / 3600
      s.save

      render json: true
    
    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def delete_schedule
    begin
      log "\n\nmethod", 'delete_schedule', 0

      PsvmSched.destroy(params[:schid].to_i) if params[:schid].present?

      render json: true
    
    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def filter
    begin
      log "\n\nmethod", 'filter', 0

      # Save the filter(s) to the session
      session[:cust_filter] = params[:cust_filter]
      render json: true

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def next_week
    begin
      log "\n\nmethod", 'next_week', 0
      session[:settings].weekstart = session[:settings].weekstart + 7.days
      redirect_to action: 'index' 
      
    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def prev_week
    begin
      log "\n\nmethod", 'prev_week', 0
      session[:settings].weekstart = session[:settings].weekstart - 7.days
      redirect_to action: 'index' 

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def generate_scheds
    begin
      log "\n\nmethod", 'generate_scheds', 0

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
            if cw.day1.id.nil? && pattern.day1.present?
              cw.day1 = convert_to_sched(filekey, custnum, @startdate + 0.days, pattern.day1)
              log 'cw-day1', cw.day1
            end
            if cw.day2.id.nil? && pattern.day2.present?
              cw.day2 = convert_to_sched(filekey, custnum, @startdate + 1.days, pattern.day2)
              log 'cw-day2', cw.day2
            end
            if cw.day3.id.nil? && pattern.day3.present?
              cw.day3 = convert_to_sched(filekey, custnum, @startdate + 2.days, pattern.day3)
              log 'cw-day3', cw.day3
            end
            if cw.day4.id.nil? && pattern.day4.present?
              cw.day4 = convert_to_sched(filekey, custnum, @startdate + 3.days, pattern.day4)
              log 'cw-day4', cw.day4
            end
            if cw.day5.id.nil? && pattern.day5.present?
              cw.day5 = convert_to_sched(filekey, custnum, @startdate + 4.days, pattern.day5)
              log 'cw-day5', cw.day5
            end
            if cw.day6.id.nil? && pattern.day6.present?
              cw.day6 = convert_to_sched(filekey, custnum, @startdate + 5.days, pattern.day6)
              log 'cw-day6', cw.day6
            end
          end
        end
      end

      redirect_to action: 'index' 

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def convert_to_sched(filekey, custnum, date, serialized)

    s = JSON[serialized]

    sch_start_time = s["start_time"]
    sch_end_time = s["end_time"]
    sch_hours_hund = s["hours"]
    sch_wg5 = s["activity"]

    sched = PsvmSched.new
    sched.sch_date = date
    sched.filekey = filekey
    sched.sch_wg3 = custnum
    sched.sch_start_time = date.midnight + Time.parse(sch_start_time).seconds_since_midnight.seconds if sch_start_time.present?
    sched.sch_end_time = date.midnight + Time.parse(sch_end_time).seconds_since_midnight.seconds if sch_end_time.present?
    sched.sch_hours_hund = sch_hours_hund if sch_hours_hund.present?
    sched.sch_wg5 = sch_wg5 if sch_wg5.present?
    sched.save

    sched
  end

end
