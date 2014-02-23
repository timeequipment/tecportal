module PluginServiceMaster

  class LoadEmployees
    include ApplicationHelper

    attr_accessor :user_id, :settings
    def initialize user_id,  settings
      @user_id = user_id
      @settings = settings
    end
    
    def perform
      log "\n\nasync method", :load_emps, 0
      begin

        # Connect to AoD
        aod = create_conn(@settings)
        
        # Get employees
        response = aod.call(
          :get_active_employees_list, message: {})  
        emps = response.body[:t_ae_employee_basic]

        emps[1..5].each do |emp|

          log 'emp', emp

          # Insert or Update this employee
          my_emp = PsvmEmp.where(filekey: emp[:filekey]).first_or_initialize
          my_emp.filekey          = emp[:filekey]
          my_emp.last_name        = emp[:last_name]
          my_emp.first_name       = emp[:first_name]
          my_emp.initial          = emp[:initial]
          my_emp.emp_id           = emp[:emp_id]
          my_emp.ssn              = emp[:ssn]
          my_emp.badge            = emp[:badge]
          my_emp.active_status    = emp[:active_status]
          my_emp.hire_date        = emp[:hire_date]
          my_emp.wg1              = emp[:wg1]
          my_emp.wg2              = emp[:wg2]
          my_emp.wg3              = emp[:wg3]
          my_emp.wg4              = emp[:wg4]
          my_emp.wg5              = emp[:wg5]
          my_emp.wg6              = emp[:wg6]
          my_emp.wg7              = emp[:wg7]
          my_emp.current_rate     = emp[:current_rate]
          my_emp.pay_type_id      = emp[:pay_type_id]
          my_emp.pay_class_id     = emp[:pay_class_id]
          my_emp.sch_patt_id      = emp[:sch_patt_id]
          my_emp.hourly_status_id = emp[:hourly_status_id]
          my_emp.clock_group_id   = emp[:clock_group_id]
          my_emp.birth_date       = emp[:birth_date]
          my_emp.custom1          = emp[:custom1]
          my_emp.custom2          = emp[:custom2]
          my_emp.custom3          = emp[:custom3]
          my_emp.custom4          = emp[:custom4]
          my_emp.custom5          = emp[:custom5]
          my_emp.custom6          = emp[:custom6]
          my_emp.save

          log 'my_emp', my_emp
        end

      rescue Exception => exc
        log 'exception', exc.message
        log 'exception backtrace', exc.backtrace
      end
    end

  end
end
