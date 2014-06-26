module PluginBambooHr

  class ImportEmployees 
    include ApplicationHelper

    attr_accessor :user_id, :settings, :lastrun
    def initialize user_id,  settings,  lastrun
      @user_i_d = user_id
      @settings = settings
      @lastrun = lastrun
    end
    
    def perform
      log "\n\nasync method", __method__, 0
      begin

        clear_messages

        log 'settings', @settings
        log 'lastrun', @lastrun

        now = DateTime.now.strftime("%Y-%m-%d")

        # Connect to AoD
        progress 15, 'Connecting to AoD'
        aod = create_conn(@settings, :debug)

        # We won't need to download payclasses or hourly status types
        # because in Bamboo the names are prefixed with the AoD num

        # # Download payclasses from AoD
        # response = aod.call(:get_pay_classes_simple, message: {})
        # payclasses = response.body
        # log 'payclasses', payclasses

        # # Download hourlystatuses from AoD
        # response = aod.call(:get_hourly_status_types_simple, message: {})  
        # hourlystatustypes = response.body
        # log 'hourlystatustypes', hourlystatustypes

        # # Download active status conditions from AoD
        # response = aod.call(:get_active_status_conditions, message: {})
        # log 'conditions', response.body[:t_ae_basic_data_item]

        # Download locations from AoD
        progress 17, 'Downloading locations from AoD'
        response = aod.call(
          :get_workgroups, message: {
            wg_level: 1,
            wg_sorting_option: 'wgsCode' })  
        locations = response.body[:t_ae_workgroup]

        # Download departments from AoD
        progress 19, 'Downloading departments from AoD'
        response = aod.call(
          :get_workgroups, message: {
            wg_level: 2,
            wg_sorting_option: 'wgsCode' })  
        departments = response.body[:t_ae_workgroup]

        # Download pay periods from AoD
        progress 19, 'Downloading pay periods from AoD'
        response = aod.call(
          :get_pay_period_class_data, message: { 
            pay_period_class_num: 1 })  
        payperiods = response.body[:t_ae_pay_period_info]
        prevstart = payperiods[:prev_start].to_datetime.strftime('%-m-%d-%Y')
        prevend   = payperiods[:prev_end]  .to_datetime.strftime('%-m-%d-%Y')
        currstart = payperiods[:curr_start].to_datetime.strftime('%-m-%d-%Y')
        currend   = payperiods[:curr_end]  .to_datetime.strftime('%-m-%d-%Y')

        # Get all employees changed since a certain date (selected by the user)
        progress 21, 'Getting employees from BambooHR'
        if @lastrun == "0"      # Last Week
          since = 1.week.ago.iso8601
        elsif @lastrun == "1"   # Last Month
          since = 1.month.ago.iso8601
        else                            # Last Year
          since = 1.year.ago.iso8601
        end
        bamboo = PluginBambooHr::Bamboo.new(
          @settings.bamboo_company,
          @settings.bamboo_key)
        emps_changed = bamboo.get_employees_changed(since)

        # For each changed emp
        emps_changed.each_with_index do |emp_changed, i|

          progress 21 + (79 * i / emps_changed.count), "Importing #{ i } of #{ emps_changed.count }"
          log "Importing emp", "#{ i } of #{ emps_changed.count }"

          # Get employee info
          b = bamboo.get_employee(emp_changed["id"].to_i, 
            "lastName,firstName,middleName,employeeNumber,customBadge,status,hireDate,location,department,payRate,payRateEffectiveDate,payType,customPayClass,customHourlyStatus,dateOfBirth,address1,address2,city,state,zipCode,customFtePercent,bestEmail,lastChanged")

          # ### DEBUG - Get a test employee from BambooHR ###
          # b = bamboo.get_employee(40408, 
          #   "lastName,firstName,middleName,employeeNumber,customBadge,status,hireDate,location,department,payRate,payRateEffectiveDate,payType,customPayClass,customHourlyStatus,dateOfBirth,address1,address2,city,state,zipCode,customFtePercent,bestEmail,lastChanged")
          # b["employeeNumber"] = 1000
          # b["firstName"] = 'Test'
          # b["lastName"] = 'Employee'
          # b["customBadge"] = 0
          # b["ssn"] = '123456789'
          # ### END DEBUG ###

          emp = {

            # AoD field                        Bamboo field (or default)
            last_name:                         b["lastName"],
            first_name:                        b["firstName"],
            initial:                           b["middleName"],
            emp_i_d:                           b["employeeNumber"],
            ssn:                               '',
            badge:                             b["customBadge"],
            active_status:                     b["status"],
            date_of_hire:                      b["hireDate"],
            wg1:                               3, 
            wg2:                               3, 
            wg3:                               1, 
            current_rate:                      b["payRate"],
            current_rate_eff_date:             b["payRateEffectiveDate"],
            active_status_condition_i_d:       0,
            inactive_status_condition_i_d:     0,
            active_status_condition_eff_date:  '',
            pay_type_i_d:                      b["payType"],
            pay_type_eff_date:                 '',
            pay_class_i_d:                     b["customPayClass"],
            pay_class_eff_date:                '',
            sch_pattern_i_d:                   0,
            sch_pattern_eff_date:              '',
            hourly_status_i_d:                 b["customHourlyStatus"],
            hourly_status_eff_date:            '',
            avg_weekly_hrs:                    0,
            clock_group_i_d:                   0,
            birth_date:                        b["dateOfBirth"],
            wg_eff_date:                       '',
            phone1:                            '',
            phone2:                            '',
            emergency_contact:                 '',
            address1:                          b["address1"],
            address2:                          b["address2"],
            address3:                          '',
            address_city:                      b["city"],
            address_state_prov:                b["state"],
            address_z_i_p_p_c:                 b["zipCode"],
            union_code:                        '',
            static_custom1:                    b["customFtePercent"],
            static_custom2:                    '',
            static_custom3:                    '',
            static_custom4:                    '',
            static_custom5:                    '',
            static_custom6:                    '',
            email:                             b["bestEmail"],
          }

          send_message "Importing employee:  #{emp[:first_name]} #{emp[:last_name]}, #{emp[:emp_i_d]}"

          # EmpID - Pad left 6 zeros
          emp[:emp_i_d] = emp[:emp_i_d].rjust(6, '0')

          # Middle Name - Get first char
          emp[:initial] = emp[:initial][0].upcase if emp[:initial].present?

          # # SSN - Remove dashes
          # emp[:sSN].gsub!('-', '') if emp[:sSN].present?

          # Email - Downcase
          emp[:email].downcase! if emp[:email].present? 

          # Active Status - translate
          if emp[:active_status] == "Active"
            emp[:active_status] = 0
          else
            emp[:active_status] = 1
          end

          # Pay Rate - strip currency suffix; cast to float
          emp[:current_rate] = emp[:current_rate].gsub(/[^\d\.]/, '').to_f

          # Pay Type - translate
          if emp[:pay_type_i_d] == "Salary"
            emp[:pay_type_i_d] = 1
            emp[:current_rate] /= 26.0
          else
            emp[:pay_type_i_d] = 0
          end

          # Pay Class - extract num from name
          /\d+/.match(emp[:pay_class_i_d]) do |m|
            emp[:pay_class_i_d] = m[0].to_i
          end

          # Hourly Status - extract num from name
          /\d+/.match(emp[:hourly_status_i_d]) do |m|
            emp[:hourly_status_i_d] = m[0].to_i
          end

          # Location - lookup mapping
          locations.each do |this|
            if this[:wg_code] == b["location"]
              emp[:wg1] = this[:wg_num].to_i
            end
          end

          # Department - lookup mapping
          departments.each do |this|
            /\d+/.match(b["department"]) do |m| # Extract dept code from name
              if this[:wg_code] == m[0]
                emp[:wg2] = this[:wg_num].to_i
              end
            end
          end

          # AoD wants a full employee record
          # So fill in the defaults with current values (if emp is found)
          a = nil
          begin
            response = aod.call(
              :get_employee_detail2_by_id_num, message: {
                id_num: emp[:emp_i_d] })  
            a = response.body[:t_ae_employee_detail2]

            # Emp exists in AoD, get current values 
            emp[:wg3]                              = a[:wg3].to_i
            emp[:current_rate_eff_date]            = a[:current_rate_eff_date].to_datetime.strftime("%Y-%m-%d")
            emp[:active_status_condition_i_d]       = a[:active_status_condition_id].to_i
            emp[:inactive_status_condition_i_d]     = a[:inactive_status_condition_id].to_i
            emp[:active_status_condition_eff_date] = a[:active_status_condition_eff_date].to_datetime.strftime("%Y-%m-%d")
            emp[:pay_type_eff_date]                = a[:pay_type_eff_date].to_datetime.strftime("%Y-%m-%d")
            emp[:pay_class_eff_date]               = a[:pay_class_eff_date].to_datetime.strftime("%Y-%m-%d")
            emp[:hourly_status_eff_date]           = a[:hourly_status_eff_date].to_datetime.strftime("%Y-%m-%d")
            emp[:wg_eff_date]                      = a[:wg_eff_date].to_datetime.strftime("%Y-%m-%d")
            emp[:sch_pattern_i_d]                   = a[:sch_pattern_id].to_i
            emp[:sch_pattern_eff_date]             = a[:sch_pattern_eff_date].to_datetime.strftime("%Y-%m-%d")
            emp[:avg_weekly_hrs]                   = a[:avg_weekly_hrs].to_i
            emp[:clock_group_i_d]                   = a[:clock_group_id].to_i
            emp[:phone1]                           = a[:phone1]            unless a[:phone1].class            == Hash
            emp[:phone2]                           = a[:phone2]            unless a[:phone2].class            == Hash
            emp[:emergency_contact]                = a[:emergency_contact] unless a[:emergency_contact].class == Hash
            emp[:address3]                         = a[:address3]          unless a[:address3].class          == Hash
            emp[:union_code]                       = a[:union_code]        unless a[:union_code].class        == Hash
            emp[:static_custom1]                   = a[:static_custom1]    unless a[:static_custom1].class    == Hash || emp[:static_custom1].present?
            emp[:static_custom2]                   = a[:static_custom2]    unless a[:static_custom2].class    == Hash
            emp[:static_custom3]                   = a[:static_custom3]    unless a[:static_custom3].class    == Hash
            emp[:static_custom4]                   = a[:static_custom4]    unless a[:static_custom4].class    == Hash
            emp[:static_custom5]                   = a[:static_custom5]    unless a[:static_custom5].class    == Hash
            emp[:static_custom6]                   = a[:static_custom6]    unless a[:static_custom6].class    == Hash

            # Get the last changed date to set for effective dates
            lastchanged = b["lastChanged"].to_datetime.strftime("%Y-%m-%d")

            log 'lastchanged', lastchanged

            # If the Active Status has changed, set effective date to today
            if emp[:active_status].to_s != a[:active_status].to_s
              emp[:active_status_condition_eff_date] = lastchanged
              send_message "Active Status changed from #{emp[:active_status]} to #{a[:active_status]} on #{lastchanged}"
            end

            # If the Current Rate has changed, set effective date to today
            if emp[:current_rate].to_s != a[:current_rate].to_s
              emp[:current_rate_eff_date] = lastchanged
              send_message "Current Rate changed from #{emp[:current_rate]} to #{a[:current_rate]} on #{lastchanged}"
            end

            # If the Pay Type has changed, set effective date to today
            if emp[:pay_type_i_d].to_s != a[:pay_type_id].to_s
              emp[:pay_type_eff_date] = lastchanged
              send_message "Pay Type changed from #{emp[:pay_type_i_d]} to #{a[:pay_type_id]} on #{lastchanged}"
            end

            # If the Pay Class has changed, set effective date to today
            if emp[:pay_class_i_d].to_s != a[:pay_class_id].to_s
              emp[:pay_class_eff_date] = lastchanged
              send_message "Pay Class changed from #{emp[:pay_class_i_d]} to #{a[:pay_class_id]} on #{lastchanged}"
            end

            # If the Hourly Status has changed, set e ffective date to today
            if emp[:hourly_status_i_d].to_s != a[:hourly_status_id].to_s
              emp[:hourly_status_eff_date] = lastchanged
              send_message "Hourly Status changed from #{emp[:hourly_status_i_d]} to #{a[:hourly_status_id]} on #{lastchanged}"
            end

            # If the Workgroup1 has changed, set effective date to today
            if emp[:wg1].to_s != a[:wg1].to_s
              emp[:wg_eff_date] = lastchanged
              send_message "Workgroup1 changed from #{emp[:wg1]} to #{a[:wg1]} on #{lastchanged}"
            end

            # If the Workgroup2 has changed, set effective date to today
            if emp[:wg2].to_s != a[:wg2].to_s
              emp[:wg_eff_date] = lastchanged
              send_message "Workgroup2 changed from #{emp[:wg2]} to #{a[:wg2]} on #{lastchanged}"
            end

            # If the Workgroup3 has changed, set effective date to today
            if emp[:wg3].to_s != a[:wg3].to_s
              emp[:wg_eff_date] = lastchanged
              send_message "Workgroup3 changed from #{emp[:wg3]} to #{a[:wg3]} on #{lastchanged}"
            end

          rescue
            # Emp does not exist in AoD, must be new
          end

          # If the employee is about to be terminated
          if emp[:active_status] == 1 
            
            # Assign them an appropriate Inactive Status Condition
            emp[:inactive_status_condition_i_d] = 1
          end

          # Send emp to AoD
          debug_import(emp, a)
          response = aod.call(:maintain_employee_detail2, 
            message: {
              ae_employee_detail2: emp,
              add_emp_mode:        "aemAuto",
              t_badge_management:  "bmAuto",
          })
          success = response.body[:maintain_employee_detail2_response][:return]
          log 'success', success
        end

      rescue Exception => exc
        log 'exception', exc.message
        log 'exception backtrace', exc.backtrace
      ensure
        progress 100, ''
        clear_messages
      end
    end

    private

    def debug_import(emp, a)
      log "FIELD NAME".ljust(30),                      "WHAT WOULD BE IMPORTED".ljust(30)                     + "WHATS IN AOD RIGHT NOW"
      log "last_name".ljust(30),                        emp[:last_name].to_s.ljust(30)                        + ( a.nil? || a[:last_name].nil?                        || a[:last_name].class == Hash ?                        '' : a[:last_name] )
      log "first_name".ljust(30),                       emp[:first_name].to_s.ljust(30)                       + ( a.nil? || a[:first_name].nil?                       || a[:first_name].class == Hash ?                       '' : a[:first_name] )
      log "initial".ljust(30),                          emp[:initial].to_s.ljust(30)                          + ( a.nil? || a[:initial].nil?                          || a[:initial].class == Hash ?                          '' : a[:initial] )
      log "emp_id".ljust(30),                           emp[:emp_i_d].to_s.ljust(30)                          + ( a.nil? || a[:emp_id].nil?                           || a[:emp_id].class == Hash ?                           '' : a[:emp_id] )
      log "ssn".ljust(30),                              emp[:ssn].to_s.ljust(30)                              + ( a.nil? || a[:ssn].nil?                              || a[:ssn].class == Hash ?                              '' : a[:ssn] )
      log "badge".ljust(30),                            emp[:badge].to_s.ljust(30)                            + ( a.nil? || a[:badge].nil?                            || a[:badge].class == Hash ?                            '' : a[:badge] )
      log "active_status".ljust(30),                    emp[:active_status].to_s.ljust(30)                    + ( a.nil? || a[:active_status].nil?                    || a[:active_status].class == Hash ?                    '' : a[:active_status] )
      log "date_of_hire".ljust(30),                     emp[:date_of_hire].to_s.ljust(30)                     + ( a.nil? || a[:date_of_hire].nil?                     || a[:date_of_hire].class == Hash ?                     '' : a[:date_of_hire] )
      log "wg1".ljust(30),                              emp[:wg1].to_s.ljust(30)                              + ( a.nil? || a[:wg1].nil?                              || a[:wg1].class == Hash ?                              '' : a[:wg1] )
      log "wg2".ljust(30),                              emp[:wg2].to_s.ljust(30)                              + ( a.nil? || a[:wg2].nil?                              || a[:wg2].class == Hash ?                              '' : a[:wg2] )
      log "wg3".ljust(30),                              emp[:wg3].to_s.ljust(30)                              + ( a.nil? || a[:wg3].nil?                              || a[:wg3].class == Hash ?                              '' : a[:wg3] )
      log "current_rate".ljust(30),                     emp[:current_rate].to_s.ljust(30)                     + ( a.nil? || a[:current_rate].nil?                     || a[:current_rate].class == Hash ?                     '' : a[:current_rate] )
      log "current_rate_eff_date".ljust(30),            emp[:current_rate_eff_date].to_s.ljust(30)            + ( a.nil? || a[:current_rate_eff_date].nil?            || a[:current_rate_eff_date].class == Hash ?            '' : a[:current_rate_eff_date] )
      log "active_status_condition_id".ljust(30),       emp[:active_status_condition_i_d].to_s.ljust(30)      + ( a.nil? || a[:active_status_condition_id].nil?       || a[:active_status_condition_id].class == Hash ?       '' : a[:active_status_condition_id] )
      log "inactive_status_condition_id".ljust(30),     emp[:inactive_status_condition_i_d].to_s.ljust(30)    + ( a.nil? || a[:inactive_status_condition_id].nil?     || a[:inactive_status_condition_id].class == Hash ?     '' : a[:inactive_status_condition_id] )
      log "active_status_condition_eff_date".ljust(30), emp[:active_status_condition_eff_date].to_s.ljust(30) + ( a.nil? || a[:active_status_condition_eff_date].nil? || a[:active_status_condition_eff_date].class == Hash ? '' : a[:active_status_condition_eff_date] )
      log "pay_type_id".ljust(30),                      emp[:pay_type_i_d].to_s.ljust(30)                     + ( a.nil? || a[:pay_type_id].nil?                      || a[:pay_type_id].class == Hash ?                      '' : a[:pay_type_id] )
      log "pay_type_eff_date".ljust(30),                emp[:pay_type_eff_date].to_s.ljust(30)                + ( a.nil? || a[:pay_type_eff_date].nil?                || a[:pay_type_eff_date].class == Hash ?                '' : a[:pay_type_eff_date] )
      log "pay_class_id".ljust(30),                     emp[:pay_class_i_d].to_s.ljust(30)                    + ( a.nil? || a[:pay_class_id].nil?                     || a[:pay_class_id].class == Hash ?                     '' : a[:pay_class_id] )
      log "pay_class_eff_date".ljust(30),               emp[:pay_class_eff_date].to_s.ljust(30)               + ( a.nil? || a[:pay_class_eff_date].nil?               || a[:pay_class_eff_date].class == Hash ?               '' : a[:pay_class_eff_date] )
      log "sch_pattern_id".ljust(30),                   emp[:sch_pattern_i_d].to_s.ljust(30)                  + ( a.nil? || a[:sch_pattern_id].nil?                   || a[:sch_pattern_id].class == Hash ?                   '' : a[:sch_pattern_id] )
      log "sch_pattern_eff_date".ljust(30),             emp[:sch_pattern_eff_date].to_s.ljust(30)             + ( a.nil? || a[:sch_pattern_eff_date].nil?             || a[:sch_pattern_eff_date].class == Hash ?             '' : a[:sch_pattern_eff_date] )
      log "hourly_status_id".ljust(30),                 emp[:hourly_status_i_d].to_s.ljust(30)                + ( a.nil? || a[:hourly_status_id].nil?                 || a[:hourly_status_id].class == Hash ?                 '' : a[:hourly_status_id] )
      log "hourly_status_eff_date".ljust(30),           emp[:hourly_status_eff_date].to_s.ljust(30)           + ( a.nil? || a[:hourly_status_eff_date].nil?           || a[:hourly_status_eff_date].class == Hash ?           '' : a[:hourly_status_eff_date] )
      log "avg_weekly_hrs".ljust(30),                   emp[:avg_weekly_hrs].to_s.ljust(30)                   + ( a.nil? || a[:avg_weekly_hrs].nil?                   || a[:avg_weekly_hrs].class == Hash ?                   '' : a[:avg_weekly_hrs] )
      log "clock_group_id".ljust(30),                   emp[:clock_group_i_d].to_s.ljust(30)                  + ( a.nil? || a[:clock_group_id].nil?                   || a[:clock_group_id].class == Hash ?                   '' : a[:clock_group_id] )
      log "birth_date".ljust(30),                       emp[:birth_date].to_s.ljust(30)                       + ( a.nil? || a[:birth_date].nil?                       || a[:birth_date].class == Hash ?                       '' : a[:birth_date] )
      log "wg_eff_date".ljust(30),                      emp[:wg_eff_date].to_s.ljust(30)                      + ( a.nil? || a[:wg_eff_date].nil?                      || a[:wg_eff_date].class == Hash ?                      '' : a[:wg_eff_date] )
      log "phone1".ljust(30),                           emp[:phone1].to_s.ljust(30)                           + ( a.nil? || a[:phone1].nil?                           || a[:phone1].class == Hash ?                           '' : a[:phone1] )
      log "phone2".ljust(30),                           emp[:phone2].to_s.ljust(30)                           + ( a.nil? || a[:phone2].nil?                           || a[:phone2].class == Hash ?                           '' : a[:phone2] )
      log "emergency_contact".ljust(30),                emp[:emergency_contact].to_s.ljust(30)                + ( a.nil? || a[:emergency_contact].nil?                || a[:emergency_contact].class == Hash ?                '' : a[:emergency_contact] )
      log "address1".ljust(30),                         emp[:address1].to_s.ljust(30)                         + ( a.nil? || a[:address1].nil?                         || a[:address1].class == Hash ?                         '' : a[:address1] )
      log "address2".ljust(30),                         emp[:address2].to_s.ljust(30)                         + ( a.nil? || a[:address2].nil?                         || a[:address2].class == Hash ?                         '' : a[:address2] )
      log "address3".ljust(30),                         emp[:address3].to_s.ljust(30)                         + ( a.nil? || a[:address3].nil?                         || a[:address3].class == Hash ?                         '' : a[:address3] )
      log "address_city".ljust(30),                     emp[:address_city].to_s.ljust(30)                     + ( a.nil? || a[:address_city].nil?                     || a[:address_city].class == Hash ?                     '' : a[:address_city] )
      log "address_state_prov".ljust(30),               emp[:address_state_prov].to_s.ljust(30)               + ( a.nil? || a[:address_state_prov].nil?               || a[:address_state_prov].class == Hash ?               '' : a[:address_state_prov] )
      log "address_zippc".ljust(30),                    emp[:address_z_i_p_p_c].to_s.ljust(30)                + ( a.nil? || a[:address_zippc].nil?                    || a[:address_zippc].class == Hash ?                    '' : a[:address_zippc] )
      log "union_code".ljust(30),                       emp[:union_code].to_s.ljust(30)                       + ( a.nil? || a[:union_code].nil?                       || a[:union_code].class == Hash ?                       '' : a[:union_code] )
      log "static_custom1".ljust(30),                   emp[:static_custom1].to_s.ljust(30)                   + ( a.nil? || a[:static_custom1].nil?                   || a[:static_custom1].class == Hash ?                   '' : a[:static_custom1] )
      log "static_custom2".ljust(30),                   emp[:static_custom2].to_s.ljust(30)                   + ( a.nil? || a[:static_custom2].nil?                   || a[:static_custom2].class == Hash ?                   '' : a[:static_custom2] )
      log "static_custom3".ljust(30),                   emp[:static_custom3].to_s.ljust(30)                   + ( a.nil? || a[:static_custom3].nil?                   || a[:static_custom3].class == Hash ?                   '' : a[:static_custom3] )
      log "static_custom4".ljust(30),                   emp[:static_custom4].to_s.ljust(30)                   + ( a.nil? || a[:static_custom4].nil?                   || a[:static_custom4].class == Hash ?                   '' : a[:static_custom4] )
      log "static_custom5".ljust(30),                   emp[:static_custom5].to_s.ljust(30)                   + ( a.nil? || a[:static_custom5].nil?                   || a[:static_custom5].class == Hash ?                   '' : a[:static_custom5] )
      log "static_custom6".ljust(30),                   emp[:static_custom6].to_s.ljust(30)                   + ( a.nil? || a[:static_custom6].nil?                   || a[:static_custom6].class == Hash ?                   '' : a[:static_custom6] )
      log "email".ljust(30),                            emp[:email].to_s.ljust(50)                            + ( a.nil? || a[:email].nil?                            || a[:email].class == Hash ?                            '' : a[:email] )
    end

    def progress(percent, status)
      cache_save @user_id, 'bhr_progress', percent.to_s
      cache_save @user_id, 'bhr_status', status
    end

    def clear_messages
      @messages = []
      cache_save @user_id, 'bhr_messages', ''
    end

    def send_message(msg)
      @messages << msg
      cache_save @user_id, 'bhr_messages', @messages.join("/n")
    end

  end
end
