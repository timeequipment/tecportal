module PluginServiceMaster

  class ImportEmployees
    include ApplicationHelper

    attr_accessor :user_id, :settings
    def initialize user_id,  settings
      @user_id = user_id
      @settings = settings
    end
    
    def perform
      log "\n\nasync method", __method__, 0
      begin

        # Connect to AoD
        aod = create_conn(@settings)
        
        # Get employees
        response = aod.call(
          :get_employees_list_detail_from_hyper_query, message: {
            hyperQueryName: 'All Employees' })  
        emps = response.body[:t_ae_employee_detail]

        empcount = 0
        emps.each do |emp|

          # Insert or Update this employee
          my_emp = PsvmEmp.where(filekey: emp[:filekey]).first_or_initialize
          my_emp.filekey          = emp[:filekey]          unless emp[:filekey].is_a? Hash
          my_emp.last_name        = emp[:last_name]        unless emp[:last_name].is_a? Hash
          my_emp.first_name       = emp[:first_name]       unless emp[:first_name].is_a? Hash
          my_emp.initial          = emp[:initial]          unless emp[:initial].is_a? Hash
          my_emp.emp_id           = emp[:emp_id]           unless emp[:emp_id].is_a? Hash
          my_emp.ssn              = emp[:ssn]              unless emp[:ssn].is_a? Hash
          my_emp.badge            = emp[:badge]            unless emp[:badge].is_a? Hash
          my_emp.active_status    = emp[:active_status]    unless emp[:active_status].is_a? Hash
          my_emp.hire_date        = emp[:hire_date]        unless emp[:hire_date].is_a? Hash
          my_emp.wg1              = emp[:wg1]              unless emp[:wg1].is_a? Hash
          my_emp.wg2              = emp[:wg2]              unless emp[:wg2].is_a? Hash
          my_emp.wg3              = emp[:wg3]              unless emp[:wg3].is_a? Hash
          my_emp.wg4              = emp[:wg4]              unless emp[:wg4].is_a? Hash
          my_emp.wg5              = emp[:wg5]              unless emp[:wg5].is_a? Hash
          my_emp.wg6              = emp[:wg6]              unless emp[:wg6].is_a? Hash
          my_emp.wg7              = emp[:wg7]              unless emp[:wg7].is_a? Hash
          my_emp.current_rate     = emp[:current_rate]     unless emp[:current_rate].is_a? Hash
          my_emp.pay_type_id      = emp[:pay_type_id]      unless emp[:pay_type_id].is_a? Hash
          my_emp.pay_class_id     = emp[:pay_class_id]     unless emp[:pay_class_id].is_a? Hash
          my_emp.sch_patt_id      = emp[:sch_patt_id]      unless emp[:sch_patt_id].is_a? Hash
          my_emp.hourly_status_id = emp[:hourly_status_id] unless emp[:hourly_status_id].is_a? Hash
          my_emp.clock_group_id   = emp[:clock_group_id]   unless emp[:clock_group_id].is_a? Hash
          my_emp.birth_date       = emp[:birth_date]       unless emp[:birth_date].is_a? Hash
          my_emp.custom1          = emp[:custom1]          unless emp[:custom1].is_a? Hash
          my_emp.custom2          = emp[:custom2]          unless emp[:custom2].is_a? Hash
          my_emp.custom3          = emp[:custom3]          unless emp[:custom3].is_a? Hash
          my_emp.custom4          = emp[:custom4]          unless emp[:custom4].is_a? Hash
          my_emp.custom5          = emp[:custom5]          unless emp[:custom5].is_a? Hash
          my_emp.custom6          = emp[:custom6]          unless emp[:custom6].is_a? Hash
          my_emp.save
          empcount += 1
        end

        # Log how many updated
        log 'Updated employees:', empcount

      rescue Exception => exc
        log 'exception', exc.message
        log 'exception backtrace', exc.backtrace
      end
    end

  end
end
