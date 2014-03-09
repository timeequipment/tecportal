class PluginServiceMasterController < ApplicationController
  before_filter :authenticate_user!
  layout "plugin_service_master"  

  @@plugin_id = 4

  def index
    begin
      log "\n\nmethod", 'index', 0
      
      # Get plugin settings for this user
      session[:settings] ||= get_settings(PluginServiceMaster::Settings, 
        current_user.id, 
        current_user.customer_id, 
        @@plugin_id)

      # Get the dates for the week we're viewing
      @startdate = session[:settings].weekstart
      @startdate ||= Date.today.beginning_of_week
      log 'startdate', @startdate
      @enddate = @startdate + 6.days

      # Get customers and activities
      @customers = PsvmWorkgroup.where('wg_level = 3').order('wg_name')
      @activities = PsvmWorkgroup.where('wg_level = 5').order('wg_name')

      # Get all employees
      @employees = PsvmEmp.where(filekey: 183).order('last_name')

      # Make a view week
      @v = PluginServiceMaster::ViewWeek.new
      @v.start_date = @startdate
      @v.end_date = @enddate
      @v.emp_weeks = get_emp_weeks(@employees, @startdate, @enddate)
      log 'v', @v

      # # Get employees that are assigned to customers
      # @employees = []
      # PsvmEmp.order('last_name').each do |emp|
      #   @employees << emp if emp.customers.any?
      # end
      
    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
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
      ew.exceptions = 'Over limit!' if ew.total_hours > 29.0

      # Save empweek
      emp_weeks << ew
    end

    emp_weeks
  end

  def get_cust_weeks employee, startdate, enddate
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
        cw.day1 = sched if sched.sch_date.strftime('%A') == 'Monday'
        cw.day2 = sched if sched.sch_date.strftime('%A') == 'Tuesday'
        cw.day3 = sched if sched.sch_date.strftime('%A') == 'Wednesday'
        cw.day4 = sched if sched.sch_date.strftime('%A') == 'Thursday'
        cw.day5 = sched if sched.sch_date.strftime('%A') == 'Friday'
        cw.day6 = sched if sched.sch_date.strftime('%A') == 'Saturday'
        cw.day7 = sched if sched.sch_date.strftime('%A') == 'Sunday'

        # Tally hours
        cw.total_hours += sched.sch_hours_hund
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
      log 'custpattern', @custpattern
      log 'customer', @customer
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
      log 'params:emp_id', params[:emp_id]
      log 'params:first_name', params[:first_name]
      log 'params:last_name', params[:last_name]
      log 'params:psvm_workgroups', params[:psvm_workgroup_ids]
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
      @employees = PsvmEmp.order('last_name, first_name')

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

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def load_schedules
    begin
      log "\n\nmethod", 'load_scheds', 0

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def save_schedule
    begin
      log "\n\nmethod", 'save_scheds', 0
      log 'params', params
    
    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def filter
    begin
      log "\n\nmethod", 'filter', 0
    
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

end
