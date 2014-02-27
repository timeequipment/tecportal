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

      # Get schedules
      @startdate = session[:settings].weekstart
      @startdate ||= Date.today.beginning_of_week
      @enddate = @startdate + 6.days
      @scheds = PsvmSched.where(sched_date: @startdate..@enddate)

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
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
      render json: @employee.to_json
      
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
      render json: [ @customer, @custpattern ].to_json
    
    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def employee_list
    begin
      log "\n\nmethod", 'employee_list', 0
      @employees = PsvmEmp.all

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def customer_list
    begin
      log "\n\nmethod", 'customer_list', 0
      @customers = PsvmWorkgroup.where(wg_level: 3)
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

  def load_scheds
    begin
      log "\n\nmethod", 'load_scheds', 0

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def save_scheds
    begin
      log "\n\nmethod", 'save_scheds', 0
    
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

  def load_customer
    begin
      log "\n\nmethod", 'load_customer', 0
    
    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def save_customer
    begin
      log "\n\nmethod", 'save_customer', 0
    
    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  private

  def get_scheds

  end
end
