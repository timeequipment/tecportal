module PluginServiceMaster

  class LoadEmployees
    include ApplicationHelper

    attr_accessor :user_id, :settings
    def initialize user_id,  settings
      @user_id = user_id
      @settings = settings
    end
    
    def perform
      log "\n\nasync method", :load_schedules, 0
      begin

        # Connect to AoD
        aod = create_conn(@settings)
        
        # Get employees
        response = aod.call(
          :get_active_employees_list, message: {})  
        emps = response.body[:t_ae_employee_basic]

        emps[1..5].each do |emp|

          log 'emp', emp

          # Only insert new emps, don't update
          found_emp = PsvmEmps.where(filekey: emp[:filekey])
          unless found_emp 
            new_emp = PsvmEmps.new
            new_emp.filekey          = emp[:filekey]
            new_emp.last_name        = emp[:last_name]
            new_emp.first_name       = emp[:first_name]
            new_emp.initial          = emp[:initial]
            new_emp.emp_id           = emp[:emp_id]
            new_emp.ssn              = emp[:ssn]
            new_emp.badge            = emp[:badge]
            new_emp.active_status    = emp[:active_status]
            new_emp.hire_date        = emp[:hire_date]
            new_emp.wg1              = emp[:wg1]
            new_emp.wg2              = emp[:wg2]
            new_emp.wg3              = emp[:wg3]
            new_emp.wg4              = emp[:wg4]
            new_emp.wg5              = emp[:wg5]
            new_emp.wg6              = emp[:wg6]
            new_emp.wg7              = emp[:wg7]
            new_emp.current_rate     = emp[:current_rate]
            new_emp.pay_type_id      = emp[:pay_type_id]
            new_emp.pay_class_id     = emp[:pay_class_id]
            new_emp.sch_patt_id      = emp[:sch_patt_id]
            new_emp.hourly_status_id = emp[:hourly_status_id]
            new_emp.clock_group_id   = emp[:clock_group_id]
            new_emp.birth_date       = emp[:birth_date]
            new_emp.custom1          = emp[:custom1]
            new_emp.custom2          = emp[:custom2]
            new_emp.custom3          = emp[:custom3]
            new_emp.custom4          = emp[:custom4]
            new_emp.custom5          = emp[:custom5]
            new_emp.custom6          = emp[:custom6]
            # new_emp.save

            log 'new_emp', new_emp
          end
        end

      rescue Exception => exc
        log 'exception', exc.message
        log 'exception backtrace', exc.backtrace
      end
    end

  end
end
