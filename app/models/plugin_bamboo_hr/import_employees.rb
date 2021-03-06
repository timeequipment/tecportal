module PluginBambooHr

  class ImportEmployees 
    include ApplicationHelper

    attr_accessor :user_id, :settings, :lastrun, :test_emp
    def initialize user_id,  settings,  lastrun,  test_emp
      @user_id = user_id
      @settings = settings
      @lastrun = lastrun
      @test_emp = test_emp
    end
    
    def perform
      log "\n\nasync method", __method__, 0
      begin
        clear_messages

        log 'settings', @settings
        log 'lastrun', @lastrun
        log 'test_emp', @test_emp

        now = DateTime.now.strftime("%Y-%m-%d")

        # Connect to AoD
        progress 15, 'Connecting to AoD'
        aod = create_conn(@settings)

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

        # Download all employees from AoD
        progress 17, 'Downloading employees from AoD'
        response = aod.call(
          :get_all_employees_list, message: {})  
        all_employees = response.body[:t_ae_employee_basic]

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
        prevstart = payperiods[:prev_start].to_datetime
        prevend   = payperiods[:prev_end]  .to_datetime
        currstart = payperiods[:curr_start].to_datetime
        currend   = payperiods[:curr_end]  .to_datetime

        bamboo = PluginBambooHr::Bamboo.new(
          @settings.bamboo_company,
          @settings.bamboo_key)

        emp_fields = "id,lastName,firstName,middleName,employeeNumber,customBadge,status,hireDate,location,department,payRate,payRateEffectiveDate,payType,customPayClass,customHourlyStatus,dateOfBirth,address1,address2,city,state,zipCode,customFtePercent,bestEmail,lastChanged"

        if @test_emp.present?
          emps = []
          emps << bamboo.get_employee(@test_emp.to_i, emp_fields)
        else
          # Get all employees changed since a certain date (selected by the user)
          progress 21, 'Getting employees from BambooHR'
          if @lastrun == "0"      # Last Week
            since = 1.week.ago.iso8601
          elsif @lastrun == "1"   # Last Month
            since = 1.month.ago.iso8601
          else                    # Last Year
            since = 1.year.ago.iso8601
          end
          emps = bamboo.get_employees_changed(since)
        end

        # For each changed emp
        emps.each_with_index do |emp_changed, i|
          begin

            progress 21 + (79 * i / emps.count), "Importing #{ i + 1 } of #{ emps.count }"
            log "Importing ", "#{ i + 1 } of #{ emps.count }"

            # Get emp id
            if emp_changed.class == Array
              emp_id = emp_changed[1]["id"].to_i
            else
              emp_id = emp_changed["id"].to_i
            end
            
            # Get employee info
            b = bamboo.get_employee(emp_id, emp_fields)

            # ### DEBUG - Get a test employee from BambooHR ###
            # b = bamboo.get_employee(40408, 
            #   "id,lastName,firstName,middleName,employeeNumber,customBadge,status,hireDate,location,department,payRate,payRateEffectiveDate,payType,customPayClass,customHourlyStatus,dateOfBirth,address1,address2,city,state,zipCode,customFtePercent,bestEmail,lastChanged")
            # b["employeeNumber"] = 1000
            # b["firstName"] = 'Test'
            # b["lastName"] = 'Employee'
            # b["customBadge"] = 0
            # b["ssn"] = '123456789'
            # ### END DEBUG ###

            # Skip deleted emps
            if b.nil?
              send_message " - Skipping Deleted Employee"
              next
            end

            emp = {

              # AoD field                        Bamboo field (or default)
              last_name:                         b["lastName"],
              first_name:                        b["firstName"],
              initial:                           b["middleName"],
              emp_i_d:                           b["employeeNumber"],
              s_s_n:                             '',
              badge:                             b["customBadge"],
              active_status:                     b["status"],
              date_of_hire:                      b["hireDate"],
              w_g_1:                             3, 
              w_g_2:                             3, 
              w_g_3:                             1, 
              current_rate:                      b["payRate"],
              current_rate_eff_date:             b["payRateEffectiveDate"],
              active_status_condition_i_d:       0,
              inactive_status_condition_i_d:     0,
              active_status_condition_eff_date:  '',
              pay_type_i_d:                      b["payType"],
              pay_type_eff_date:                 '',
              pay_class_i_d:                     b["customPayClass"],
              pay_class_eff_date:                '',
              sch_pattern_i_d:                   1,
              sch_pattern_eff_date:              '',
              hourly_status_i_d:                 b["customHourlyStatus"],
              hourly_status_eff_date:            '',
              avg_weekly_hrs:                    0,
              clock_group_i_d:                   1,
              birth_date:                        b["dateOfBirth"],
              w_g_eff_date:                      '',
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
              e_m_a_i_l:                         b["bestEmail"],
            }

            send_message "Importing #{ i + 1 } of #{ emps.count }:  #{emp[:first_name]} #{emp[:last_name]}, AoD ##{emp[:emp_i_d]}, BambooHR ##{b["id"]}"

            # EmpID - if nil, fail
            raise "Missing AoD # in BambooHR; Unable to lookup AoD employee" if emp[:emp_i_d].nil?
            
            # EmpID - Pad left 6 zeros
            emp[:emp_i_d] = emp[:emp_i_d].rjust(6, '0')

            # Middle Name - Get first char
            emp[:initial] = emp[:initial][0].upcase if emp[:initial].present?

            # # SSN - Remove dashes
            # emp[:sSN].gsub!('-', '') if emp[:sSN].present?

            # Email - Downcase
            emp[:e_m_a_i_l].downcase! if emp[:e_m_a_i_l].present? 

            # Active Status - translate
            if emp[:active_status] == "Active"
              emp[:active_status] = 0
              emp[:active_status_condition_i_d] = 1
            else
              emp[:active_status] = 1
              emp[:inactive_status_condition_i_d] = 1
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

            # Pay Rate - round to hundredths
            emp[:current_rate] = emp[:current_rate].to_f.round(2)

            # Pay Class - extract num from name
            /\d+/.match(emp[:pay_class_i_d]) do |m|
              emp[:pay_class_i_d] = m[0].to_i
            end

            # Hourly Status - extract num from name
            /\d+/.match(emp[:hourly_status_i_d]) do |m|
              emp[:hourly_status_i_d] = m[0].to_i
            end

            # Address Zip Code - take first 5 digits
            if emp[:address_z_i_p_p_c].present? && emp[:address_z_i_p_p_c].length > 5
              emp[:address_z_i_p_p_c] = emp[:address_z_i_p_p_c][0..4]
            end

            # Location - lookup mapping
            locations.each do |this|
              if this[:wg_code] == b["location"]
                emp[:w_g_1] = this[:wg_num].to_i
              end
            end

            # Department - lookup mapping
            departments.each do |this|
              /\d+/.match(b["department"]) do |m| # Extract dept code from name
                if this[:wg_code] == m[0]
                  emp[:w_g_2] = this[:wg_num].to_i
                end
              end
            end

            # See if this employee exists in AoD
            found = false
            all_employees.each do |this_emp|
              if emp[:emp_i_d].to_s == this_emp[:emp_id].to_s
                found = true
                log 'found', this_emp[:emp_id].to_s 
                break
              end
            end
            if !found
              send_message " - ** New Employee **"
            else

              # Get the employee from AoD
              response = aod.call(
                :get_employee_detail2_by_id_num, message: {
                  id_num: emp[:emp_i_d] })  
              a = response.body[:t_ae_employee_detail2]

              # Emp exists in AoD, get current values 
              emp[:w_g_3]                            = a[:wg3].to_i
              emp[:current_rate_eff_date]            = a[:current_rate_eff_date].to_datetime.strftime("%Y-%m-%d")
              emp[:active_status_condition_eff_date] = a[:active_status_condition_eff_date].to_datetime.strftime("%Y-%m-%d")
              emp[:pay_type_eff_date]                = a[:pay_type_eff_date].to_datetime.strftime("%Y-%m-%d")
              emp[:pay_class_eff_date]               = a[:pay_class_eff_date].to_datetime.strftime("%Y-%m-%d")
              emp[:hourly_status_eff_date]           = a[:hourly_status_eff_date].to_datetime.strftime("%Y-%m-%d")
              emp[:w_g_eff_date]                     = a[:wg_eff_date].to_datetime.strftime("%Y-%m-%d")
              emp[:sch_pattern_i_d]                  = a[:sch_pattern_id].to_i
              emp[:sch_pattern_eff_date]             = a[:sch_pattern_eff_date].to_datetime.strftime("%Y-%m-%d")
              emp[:avg_weekly_hrs]                   = a[:avg_weekly_hrs].to_i
              emp[:clock_group_i_d]                  = a[:clock_group_id].to_i
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

              # If the badge is blank, set it to the AoD badge
              if emp[:badge].to_s.blank?
                emp[:badge] = a[:badge]
              end

              # If the Active Status has changed, set effective date to today
              if emp[:active_status].to_s != a[:active_status].to_s
                emp[:active_status_condition_eff_date] = now
              end

              # If the Current Rate has changed, set effective date to 'lastchanged'
              if emp[:current_rate].to_f.round(2) != a[:current_rate].to_f.round(2)
                emp[:current_rate_eff_date] = lastchanged
              end

              # If the Pay Type has changed, set effective date to 'lastchanged'
              if emp[:pay_type_i_d].to_s != a[:pay_type_id].to_s
                emp[:pay_type_eff_date] = lastchanged
              end

              # If the Pay Class has changed
              if emp[:pay_class_i_d].to_s != a[:pay_class_id].to_s
                
                lastc = b["lastChanged"].to_datetime

                # If lastchanged is in curr period
                if lastc.between?(currstart, currend)
                  # Set effective date to curr start
                  emp[:pay_class_eff_date] = currstart
                
                # If lastchanged is in prev period
                elsif lastc.between?(prevstart, prevend)
                  # Set effective date to prev start
                  emp[:pay_class_eff_date] = prevstart
                end
              end

              # If the Hourly Status has changed, set effective date to 'lastchanged'
              if emp[:hourly_status_i_d].to_s != a[:hourly_status_id].to_s
                emp[:hourly_status_eff_date] = lastchanged
              end

              # If the Workgroup1 has changed, set effective date to 'lastchanged'
              if emp[:w_g_1].to_s != a[:wg1].to_s
                emp[:w_g_eff_date] = lastchanged
              end

              # If the Workgroup2 has changed, set effective date to 'lastchanged'
              if emp[:w_g_2].to_s != a[:wg2].to_s
                emp[:w_g_eff_date] = lastchanged
              end

              # If the Workgroup3 has changed, set effective date to 'lastchanged'
              if emp[:w_g_3].to_s != a[:wg3].to_s
                emp[:w_g_eff_date] = lastchanged
              end

              # Clean up record
              emp = clean_up_record emp

              # Send change messages
              emp_last_name                        = ( emp[:last_name].to_s.blank?                        ? '(blank)' : emp[:last_name].to_s )
              emp_first_name                       = ( emp[:first_name].to_s.blank?                       ? '(blank)' : emp[:first_name].to_s )
              emp_initial                          = ( emp[:initial].to_s.blank?                          ? '(blank)' : emp[:initial].to_s )
              emp_emp_id                           = ( emp[:emp_i_d].to_s.blank?                          ? '(blank)' : emp[:emp_i_d].to_s )
              emp_ssn                              = ( emp[:s_s_n].to_s.blank?                            ? '(blank)' : emp[:s_s_n].to_s )
              emp_badge                            = ( emp[:badge].to_s.blank?                            ? '(blank)' : emp[:badge].to_s )
              emp_active_status                    = ( emp[:active_status].to_s.blank?                    ? '(blank)' : emp[:active_status].to_s )
              emp_date_of_hire                     = ( emp[:date_of_hire].to_s.blank?                     ? '(blank)' : emp[:date_of_hire].to_s )
              emp_wg1                              = ( emp[:w_g_1].to_s.blank?                            ? '(blank)' : emp[:w_g_1].to_s )
              emp_wg2                              = ( emp[:w_g_2].to_s.blank?                            ? '(blank)' : emp[:w_g_2].to_s )
              emp_wg3                              = ( emp[:w_g_3].to_s.blank?                            ? '(blank)' : emp[:w_g_3].to_s )
              emp_current_rate                     = ( emp[:current_rate].to_f.round(2).to_s.blank?       ? '(blank)' : emp[:current_rate].to_f.round(2).to_s )
              emp_current_rate_eff_date            = ( emp[:current_rate_eff_date].to_s.blank?            ? '(blank)' : emp[:current_rate_eff_date].to_s )
              emp_active_status_condition_id       = ( emp[:active_status_condition_i_d].to_s.blank?      ? '(blank)' : emp[:active_status_condition_i_d].to_s )
              emp_inactive_status_condition_id     = ( emp[:inactive_status_condition_i_d].to_s.blank?    ? '(blank)' : emp[:inactive_status_condition_i_d].to_s )
              emp_active_status_condition_eff_date = ( emp[:active_status_condition_eff_date].to_s.blank? ? '(blank)' : emp[:active_status_condition_eff_date].to_s )
              emp_pay_type_id                      = ( emp[:pay_type_i_d].to_s.blank?                     ? '(blank)' : emp[:pay_type_i_d].to_s )
              emp_pay_type_eff_date                = ( emp[:pay_type_eff_date].to_s.blank?                ? '(blank)' : emp[:pay_type_eff_date].to_s )
              emp_pay_class_id                     = ( emp[:pay_class_i_d].to_s.blank?                    ? '(blank)' : emp[:pay_class_i_d].to_s )
              emp_pay_class_eff_date               = ( emp[:pay_class_eff_date].to_s.blank?               ? '(blank)' : emp[:pay_class_eff_date].to_s )
              emp_sch_pattern_id                   = ( emp[:sch_pattern_i_d].to_s.blank?                  ? '(blank)' : emp[:sch_pattern_i_d].to_s )
              emp_sch_pattern_eff_date             = ( emp[:sch_pattern_eff_date].to_s.blank?             ? '(blank)' : emp[:sch_pattern_eff_date].to_s )
              emp_hourly_status_id                 = ( emp[:hourly_status_i_d].to_s.blank?                ? '(blank)' : emp[:hourly_status_i_d].to_s )
              emp_hourly_status_eff_date           = ( emp[:hourly_status_eff_date].to_s.blank?           ? '(blank)' : emp[:hourly_status_eff_date].to_s )
              emp_avg_weekly_hrs                   = ( emp[:avg_weekly_hrs].to_s.blank?                   ? '(blank)' : emp[:avg_weekly_hrs].to_s )
              emp_clock_group_id                   = ( emp[:clock_group_i_d].to_s.blank?                  ? '(blank)' : emp[:clock_group_i_d].to_s )
              emp_birth_date                       = ( emp[:birth_date].to_s.blank?                       ? '(blank)' : emp[:birth_date].to_s )
              emp_wg_eff_date                      = ( emp[:w_g_eff_date].to_s.blank?                     ? '(blank)' : emp[:w_g_eff_date].to_s )
              emp_phone1                           = ( emp[:phone1].to_s.blank?                           ? '(blank)' : emp[:phone1].to_s )
              emp_phone2                           = ( emp[:phone2].to_s.blank?                           ? '(blank)' : emp[:phone2].to_s )
              emp_emergency_contact                = ( emp[:emergency_contact].to_s.blank?                ? '(blank)' : emp[:emergency_contact].to_s )
              emp_address1                         = ( emp[:address1].to_s.blank?                         ? '(blank)' : emp[:address1].to_s )
              emp_address2                         = ( emp[:address2].to_s.blank?                         ? '(blank)' : emp[:address2].to_s )
              emp_address3                         = ( emp[:address3].to_s.blank?                         ? '(blank)' : emp[:address3].to_s )
              emp_address_city                     = ( emp[:address_city].to_s.blank?                     ? '(blank)' : emp[:address_city].to_s )
              emp_address_state_prov               = ( emp[:address_state_prov].to_s.blank?               ? '(blank)' : emp[:address_state_prov].to_s )
              emp_address_zippc                    = ( emp[:address_z_i_p_p_c].to_s.blank?                ? '(blank)' : emp[:address_z_i_p_p_c].to_s )
              emp_union_code                       = ( emp[:union_code].to_s.blank?                       ? '(blank)' : emp[:union_code].to_s )
              emp_static_custom1                   = ( emp[:static_custom1].to_s.blank?                   ? '(blank)' : emp[:static_custom1].to_s )
              emp_static_custom2                   = ( emp[:static_custom2].to_s.blank?                   ? '(blank)' : emp[:static_custom2].to_s )
              emp_static_custom3                   = ( emp[:static_custom3].to_s.blank?                   ? '(blank)' : emp[:static_custom3].to_s )
              emp_static_custom4                   = ( emp[:static_custom4].to_s.blank?                   ? '(blank)' : emp[:static_custom4].to_s )
              emp_static_custom5                   = ( emp[:static_custom5].to_s.blank?                   ? '(blank)' : emp[:static_custom5].to_s )
              emp_static_custom6                   = ( emp[:static_custom6].to_s.blank?                   ? '(blank)' : emp[:static_custom6].to_s )
              emp_email                            = ( emp[:e_m_a_i_l].to_s.blank?                        ? '(blank)' : emp[:e_m_a_i_l].to_s )

              aod_last_name                        = ( a[:last_name].to_s.blank?                        || a[:last_name].class == Hash ?                        '(blank)' : a[:last_name].to_s )
              aod_first_name                       = ( a[:first_name].to_s.blank?                       || a[:first_name].class == Hash ?                       '(blank)' : a[:first_name].to_s )
              aod_initial                          = ( a[:initial].to_s.blank?                          || a[:initial].class == Hash ?                          '(blank)' : a[:initial].to_s )
              aod_emp_id                           = ( a[:emp_id].to_s.blank?                           || a[:emp_id].class == Hash ?                           '(blank)' : a[:emp_id].to_s )
              aod_ssn                              = ( a[:ssn].to_s.blank?                              || a[:ssn].class == Hash ?                              '(blank)' : a[:ssn].to_s )
              aod_badge                            = ( a[:badge].to_s.blank?                            || a[:badge].class == Hash ?                            '(blank)' : a[:badge].to_s )
              aod_active_status                    = ( a[:active_status].to_s.blank?                    || a[:active_status].class == Hash ?                    '(blank)' : a[:active_status].to_s )
              aod_date_of_hire                     = ( a[:date_of_hire].to_s.blank?                     || a[:date_of_hire].class == Hash ?                     '(blank)' : a[:date_of_hire].to_datetime.strftime("%Y-%m-%d").to_s )
              aod_wg1                              = ( a[:wg1].to_s.blank?                              || a[:wg1].class == Hash ?                              '(blank)' : a[:wg1].to_s )
              aod_wg2                              = ( a[:wg2].to_s.blank?                              || a[:wg2].class == Hash ?                              '(blank)' : a[:wg2].to_s )
              aod_wg3                              = ( a[:wg3].to_s.blank?                              || a[:wg3].class == Hash ?                              '(blank)' : a[:wg3].to_s )
              aod_current_rate                     = ( a[:current_rate].to_f.round(2).to_s.blank?       || a[:current_rate].class == Hash ?                     '(blank)' : a[:current_rate].to_f.round(2).to_s )
              aod_current_rate_eff_date            = ( a[:current_rate_eff_date].to_s.blank?            || a[:current_rate_eff_date].class == Hash ?            '(blank)' : a[:current_rate_eff_date].to_datetime.strftime("%Y-%m-%d").to_s )
              aod_active_status_condition_id       = ( a[:active_status_condition_id].to_s.blank?       || a[:active_status_condition_id].class == Hash ?       '(blank)' : a[:active_status_condition_id].to_s )
              aod_inactive_status_condition_id     = ( a[:inactive_status_condition_id].to_s.blank?     || a[:inactive_status_condition_id].class == Hash ?     '(blank)' : a[:inactive_status_condition_id].to_s )
              aod_active_status_condition_eff_date = ( a[:active_status_condition_eff_date].to_s.blank? || a[:active_status_condition_eff_date].class == Hash ? '(blank)' : a[:active_status_condition_eff_date].to_datetime.strftime("%Y-%m-%d").to_s )
              aod_pay_type_id                      = ( a[:pay_type_id].to_s.blank?                      || a[:pay_type_id].class == Hash ?                      '(blank)' : a[:pay_type_id].to_s )
              aod_pay_type_eff_date                = ( a[:pay_type_eff_date].to_s.blank?                || a[:pay_type_eff_date].class == Hash ?                '(blank)' : a[:pay_type_eff_date].to_datetime.strftime("%Y-%m-%d").to_s )
              aod_pay_class_id                     = ( a[:pay_class_id].to_s.blank?                     || a[:pay_class_id].class == Hash ?                     '(blank)' : a[:pay_class_id].to_s )
              aod_pay_class_eff_date               = ( a[:pay_class_eff_date].to_s.blank?               || a[:pay_class_eff_date].class == Hash ?               '(blank)' : a[:pay_class_eff_date].to_datetime.strftime("%Y-%m-%d").to_s )
              aod_sch_pattern_id                   = ( a[:sch_pattern_id].to_s.blank?                   || a[:sch_pattern_id].class == Hash ?                   '(blank)' : a[:sch_pattern_id].to_s )
              aod_sch_pattern_eff_date             = ( a[:sch_pattern_eff_date].to_s.blank?             || a[:sch_pattern_eff_date].class == Hash ?             '(blank)' : a[:sch_pattern_eff_date].to_datetime.strftime("%Y-%m-%d").to_s )
              aod_hourly_status_id                 = ( a[:hourly_status_id].to_s.blank?                 || a[:hourly_status_id].class == Hash ?                 '(blank)' : a[:hourly_status_id].to_s )
              aod_hourly_status_eff_date           = ( a[:hourly_status_eff_date].to_s.blank?           || a[:hourly_status_eff_date].class == Hash ?           '(blank)' : a[:hourly_status_eff_date].to_datetime.strftime("%Y-%m-%d").to_s )
              aod_avg_weekly_hrs                   = ( a[:avg_weekly_hrs].to_s.blank?                   || a[:avg_weekly_hrs].class == Hash ?                   '(blank)' : a[:avg_weekly_hrs].to_s )
              aod_clock_group_id                   = ( a[:clock_group_id].to_s.blank?                   || a[:clock_group_id].class == Hash ?                   '(blank)' : a[:clock_group_id].to_s )
              aod_birth_date                       = ( a[:birth_date].to_s.blank?                       || a[:birth_date].class == Hash ?                       '(blank)' : a[:birth_date].to_datetime.strftime("%Y-%m-%d").to_s )
              aod_wg_eff_date                      = ( a[:wg_eff_date].to_s.blank?                      || a[:wg_eff_date].class == Hash ?                      '(blank)' : a[:wg_eff_date].to_datetime.strftime("%Y-%m-%d").to_s )
              aod_phone1                           = ( a[:phone1].to_s.blank?                           || a[:phone1].class == Hash ?                           '(blank)' : a[:phone1].to_s )
              aod_phone2                           = ( a[:phone2].to_s.blank?                           || a[:phone2].class == Hash ?                           '(blank)' : a[:phone2].to_s )
              aod_emergency_contact                = ( a[:emergency_contact].to_s.blank?                || a[:emergency_contact].class == Hash ?                '(blank)' : a[:emergency_contact].to_s )
              aod_address1                         = ( a[:address1].to_s.blank?                         || a[:address1].class == Hash ?                         '(blank)' : a[:address1].to_s )
              aod_address2                         = ( a[:address2].to_s.blank?                         || a[:address2].class == Hash ?                         '(blank)' : a[:address2].to_s )
              aod_address3                         = ( a[:address3].to_s.blank?                         || a[:address3].class == Hash ?                         '(blank)' : a[:address3].to_s )
              aod_address_city                     = ( a[:address_city].to_s.blank?                     || a[:address_city].class == Hash ?                     '(blank)' : a[:address_city].to_s )
              aod_address_state_prov               = ( a[:address_state_prov].to_s.blank?               || a[:address_state_prov].class == Hash ?               '(blank)' : a[:address_state_prov].to_s )
              aod_address_zippc                    = ( a[:address_zippc].to_s.blank?                    || a[:address_zippc].class == Hash ?                    '(blank)' : a[:address_zippc].to_s )
              aod_union_code                       = ( a[:union_code].to_s.blank?                       || a[:union_code].class == Hash ?                       '(blank)' : a[:union_code].to_s )
              aod_static_custom1                   = ( a[:static_custom1].to_s.blank?                   || a[:static_custom1].class == Hash ?                   '(blank)' : a[:static_custom1].to_s )
              aod_static_custom2                   = ( a[:static_custom2].to_s.blank?                   || a[:static_custom2].class == Hash ?                   '(blank)' : a[:static_custom2].to_s )
              aod_static_custom3                   = ( a[:static_custom3].to_s.blank?                   || a[:static_custom3].class == Hash ?                   '(blank)' : a[:static_custom3].to_s )
              aod_static_custom4                   = ( a[:static_custom4].to_s.blank?                   || a[:static_custom4].class == Hash ?                   '(blank)' : a[:static_custom4].to_s )
              aod_static_custom5                   = ( a[:static_custom5].to_s.blank?                   || a[:static_custom5].class == Hash ?                   '(blank)' : a[:static_custom5].to_s )
              aod_static_custom6                   = ( a[:static_custom6].to_s.blank?                   || a[:static_custom6].class == Hash ?                   '(blank)' : a[:static_custom6].to_s )
              aod_email                            = ( a[:email].to_s.blank?                            || a[:email].class == Hash ?                            '(blank)' : a[:email].to_s )

              if emp_last_name != aod_last_name
                send_message " - Last Name changed from #{aod_last_name} to #{emp_last_name}"
              end

              if emp_first_name != aod_first_name
                send_message " - First Name changed from #{aod_first_name} to #{emp_first_name}"
              end

              if emp_initial != aod_initial
                send_message " - Initial changed from #{aod_initial} to #{emp_initial}"
              end

              if emp_emp_id != aod_emp_id
                send_message " - Emp ID changed from #{aod_emp_id} to #{emp_emp_id}"
              end

              if emp_ssn != aod_ssn
                send_message " - Ssn changed from #{aod_ssn} to #{emp_ssn}"
              end

              if emp_badge != aod_badge
                send_message " - Badge changed from #{aod_badge} to #{emp_badge}"
              end

              if emp_active_status != aod_active_status
                send_message " - Active Status changed from #{aod_active_status} to #{emp_active_status} on #{lastchanged}"
              end

              if emp_date_of_hire != aod_date_of_hire
                send_message " - Date Of Hire changed from #{aod_date_of_hire} to #{emp_date_of_hire} on #{lastchanged}"
              end

              if emp_wg1 != aod_wg1
                send_message " - Wg1 changed from #{aod_wg1} to #{emp_wg1} on #{lastchanged}"
              end

              if emp_wg2 != aod_wg2
                send_message " - Wg2 changed from #{aod_wg2} to #{emp_wg2} on #{lastchanged}"
              end

              if emp_wg3 != aod_wg3
                send_message " - Wg3 changed from #{aod_wg3} to #{emp_wg3} on #{lastchanged}"
              end

              if emp_current_rate != aod_current_rate
                send_message " - Current Rate changed from #{aod_current_rate} to #{emp_current_rate} on #{lastchanged}"
              end

              if emp_pay_type_id != aod_pay_type_id
                send_message " - Pay Type ID changed from #{aod_pay_type_id} to #{emp_pay_type_id} on #{lastchanged}"
              end

              if emp_pay_class_id != aod_pay_class_id
                send_message " - Pay Class ID changed from #{aod_pay_class_id} to #{emp_pay_class_id} on #{lastchanged}"
              end

              if emp_sch_pattern_id != aod_sch_pattern_id
                send_message " - Sch Pattern ID changed from #{aod_sch_pattern_id} to #{emp_sch_pattern_id} on #{lastchanged}"
              end

              if emp_hourly_status_id != aod_hourly_status_id
                send_message " - Hourly Status ID changed from #{aod_hourly_status_id} to #{emp_hourly_status_id} on #{lastchanged}"
              end

              if emp_avg_weekly_hrs != aod_avg_weekly_hrs
                send_message " - Avg Weekly Hrs changed from #{aod_avg_weekly_hrs} to #{emp_avg_weekly_hrs}"
              end

              if emp_clock_group_id != aod_clock_group_id
                send_message " - Clock Group ID changed from #{aod_clock_group_id} to #{emp_clock_group_id}"
              end

              if emp_birth_date != aod_birth_date
                send_message " - Birth Date changed from #{aod_birth_date} to #{emp_birth_date}"
              end

              if emp_phone1 != aod_phone1
                send_message " - Phone1 changed from #{aod_phone1} to #{emp_phone1}"
              end

              if emp_phone2 != aod_phone2
                send_message " - Phone2 changed from #{aod_phone2} to #{emp_phone2}"
              end

              if emp_emergency_contact != aod_emergency_contact
                send_message " - Emergency Contact changed from #{aod_emergency_contact} to #{emp_emergency_contact}"
              end

              if emp_address1 != aod_address1
                send_message " - Address1 changed from #{aod_address1} to #{emp_address1}"
              end

              if emp_address2 != aod_address2
                send_message " - Address2 changed from #{aod_address2} to #{emp_address2}"
              end

              if emp_address3 != aod_address3
                send_message " - Address3 changed from #{aod_address3} to #{emp_address3}"
              end

              if emp_address_city != aod_address_city
                send_message " - Address City changed from #{aod_address_city} to #{emp_address_city}"
              end

              if emp_address_state_prov != aod_address_state_prov
                send_message " - Address State Prov changed from #{aod_address_state_prov} to #{emp_address_state_prov}"
              end

              if emp_address_zippc != aod_address_zippc
                send_message " - Address Zip changed from #{aod_address_zippc} to #{emp_address_zippc}"
              end

              if emp_union_code != aod_union_code
                send_message " - Union Code changed from #{aod_union_code} to #{emp_union_code}"
              end

              if emp_static_custom1 != aod_static_custom1
                send_message " - Static Custom1 changed from #{aod_static_custom1} to #{emp_static_custom1}"
              end

              if emp_static_custom2 != aod_static_custom2
                send_message " - Static Custom2 changed from #{aod_static_custom2} to #{emp_static_custom2}"
              end

              if emp_static_custom3 != aod_static_custom3
                send_message " - Static Custom3 changed from #{aod_static_custom3} to #{emp_static_custom3}"
              end

              if emp_static_custom4 != aod_static_custom4
                send_message " - Static Custom4 changed from #{aod_static_custom4} to #{emp_static_custom4}"
              end

              if emp_static_custom5 != aod_static_custom5
                send_message " - Static Custom5 changed from #{aod_static_custom5} to #{emp_static_custom5}"
              end

              if emp_static_custom6 != aod_static_custom6
                send_message " - Static Custom6 changed from #{aod_static_custom6} to #{emp_static_custom6}"
              end

              if emp_email != aod_email
                send_message " - Email changed from #{aod_email} to #{emp_email}"
              end
            end

            # Send emp to AoD
            debug_import(emp, a)
            response = aod.call(:maintain_employee_detail2, 
              message: {
                ae_employee_detail2: emp,
                add_emp_mode:        "aemAuto",
                t_badge_management:  (emp[:badge].to_s.blank? ? "bmAuto" : "bmManual"),
            })
            success = response.body[:maintain_employee_detail2_response][:return]

            if success == "merEditOk" || success == "merAddOk"
              # do nothing
            elsif success == "merAddedWithErrors"
              send_message " - IMPORT FAILED - Emp Added, but with errors"
            elsif success == "merBadParam"
              send_message " - IMPORT FAILED - Bad Parameter"
            elsif success == "merDupID"
              send_message " - IMPORT FAILED - Duplicate ID"
            elsif success == "merDupBadge"
              send_message " - IMPORT FAILED - Duplicate Badge"
            else
              send_message " - IMPORT FAILED - Unknown Reason"
            end

          rescue Exception => exc
            log_exception exc
            send_message " - IMPORT FAILED - #{exc.message}"
          end
        end

      rescue Exception => exc
        log_exception exc
        send_message " - IMPORT FAILED - #{exc.message}"
      ensure
        progress 100, ''
      end
    end

    private

    def clean_up_record emp
      now = DateTime.now.strftime("%Y-%m-%d")
      emp[:last_name]                        = ''  if emp[:last_name].to_s.blank? 
      emp[:first_name]                       = ''  if emp[:first_name].to_s.blank? 
      emp[:initial]                          = ''  if emp[:initial].to_s.blank? 
      emp[:emp_i_d]                          = ''  if emp[:emp_i_d].to_s.blank? 
      emp[:s_s_n]                            = ''  if emp[:s_s_n].to_s.blank? 
      emp[:badge]                            = 0   if emp[:badge].to_s.blank? 
      emp[:active_status]                    = 0   if emp[:active_status].to_s.blank? 
      emp[:date_of_hire]                     = now if emp[:date_of_hire].to_s.blank? 
      emp[:w_g_1]                            = 3   if emp[:w_g_1].to_s.blank? 
      emp[:w_g_2]                            = 3   if emp[:w_g_2].to_s.blank? 
      emp[:w_g_3]                            = 1   if emp[:w_g_3].to_s.blank? 
      emp[:current_rate]                     = ''  if emp[:current_rate].to_s.blank? 
      emp[:current_rate_eff_date]            = ''  if emp[:current_rate_eff_date].to_s.blank? 
      emp[:active_status_condition_i_d]      = 0   if emp[:active_status_condition_i_d].to_s.blank? 
      emp[:inactive_status_condition_i_d]    = 0   if emp[:inactive_status_condition_i_d].to_s.blank? 
      emp[:active_status_condition_eff_date] = now if emp[:active_status_condition_eff_date].to_s.blank? 
      emp[:pay_type_i_d]                     = 1   if emp[:pay_type_i_d].to_s.blank? 
      emp[:pay_type_eff_date]                = now if emp[:pay_type_eff_date].to_s.blank? 
      emp[:pay_class_i_d]                    = 1   if emp[:pay_class_i_d].to_s.blank? 
      emp[:pay_class_eff_date]               = now if emp[:pay_class_eff_date].to_s.blank? 
      emp[:sch_pattern_i_d]                  = 1   if emp[:sch_pattern_i_d].to_s.blank? 
      emp[:sch_pattern_eff_date]             = now if emp[:sch_pattern_eff_date].to_s.blank? 
      emp[:hourly_status_i_d]                = 1   if emp[:hourly_status_i_d].to_s.blank? 
      emp[:hourly_status_eff_date]           = now if emp[:hourly_status_eff_date].to_s.blank? 
      emp[:avg_weekly_hrs]                   = ''  if emp[:avg_weekly_hrs].to_s.blank? 
      emp[:clock_group_i_d]                  = 1   if emp[:clock_group_i_d].to_s.blank? 
      emp[:birth_date]                       = now if emp[:birth_date].to_s.blank? 
      emp[:w_g_eff_date]                     = now if emp[:w_g_eff_date].to_s.blank? 
      emp[:phone1]                           = ''  if emp[:phone1].to_s.blank? 
      emp[:phone2]                           = ''  if emp[:phone2].to_s.blank? 
      emp[:emergency_contact]                = ''  if emp[:emergency_contact].to_s.blank? 
      emp[:address1]                         = ''  if emp[:address1].to_s.blank? 
      emp[:address2]                         = ''  if emp[:address2].to_s.blank? 
      emp[:address3]                         = ''  if emp[:address3].to_s.blank? 
      emp[:address_city]                     = ''  if emp[:address_city].to_s.blank? 
      emp[:address_state_prov]               = ''  if emp[:address_state_prov].to_s.blank? 
      emp[:address_z_i_p_p_c]                = ''  if emp[:address_z_i_p_p_c].to_s.blank? 
      emp[:union_code]                       = ''  if emp[:union_code].to_s.blank? 
      emp[:static_custom1]                   = ''  if emp[:static_custom1].to_s.blank? 
      emp[:static_custom2]                   = ''  if emp[:static_custom2].to_s.blank? 
      emp[:static_custom3]                   = ''  if emp[:static_custom3].to_s.blank? 
      emp[:static_custom4]                   = ''  if emp[:static_custom4].to_s.blank? 
      emp[:static_custom5]                   = ''  if emp[:static_custom5].to_s.blank? 
      emp[:static_custom6]                   = ''  if emp[:static_custom6].to_s.blank? 
      emp[:e_m_a_i_l]                        = ''  if emp[:e_m_a_i_l].to_s.blank? 
      emp
    end

    def debug_import(emp, a)
      log "FIELD NAME".ljust(30),                      "WHAT WOULD BE IMPORTED".ljust(30)                     + "WHATS IN AOD RIGHT NOW"
      log "last_name".ljust(30),                        emp[:last_name].to_s.ljust(30)                        + ( a.nil? || a[:last_name].nil?                        || a[:last_name].class == Hash ?                        '' : a[:last_name] )
      log "first_name".ljust(30),                       emp[:first_name].to_s.ljust(30)                       + ( a.nil? || a[:first_name].nil?                       || a[:first_name].class == Hash ?                       '' : a[:first_name] )
      log "initial".ljust(30),                          emp[:initial].to_s.ljust(30)                          + ( a.nil? || a[:initial].nil?                          || a[:initial].class == Hash ?                          '' : a[:initial] )
      log "emp_id".ljust(30),                           emp[:emp_i_d].to_s.ljust(30)                          + ( a.nil? || a[:emp_id].nil?                           || a[:emp_id].class == Hash ?                           '' : a[:emp_id] )
      log "ssn".ljust(30),                              emp[:s_s_n].to_s.ljust(30)                            + ( a.nil? || a[:ssn].nil?                              || a[:ssn].class == Hash ?                              '' : a[:ssn] )
      log "badge".ljust(30),                            emp[:badge].to_s.ljust(30)                            + ( a.nil? || a[:badge].nil?                            || a[:badge].class == Hash ?                            '' : a[:badge] )
      log "active_status".ljust(30),                    emp[:active_status].to_s.ljust(30)                    + ( a.nil? || a[:active_status].nil?                    || a[:active_status].class == Hash ?                    '' : a[:active_status] )
      log "date_of_hire".ljust(30),                     emp[:date_of_hire].to_s.ljust(30)                     + ( a.nil? || a[:date_of_hire].nil?                     || a[:date_of_hire].class == Hash ?                     '' : a[:date_of_hire] )
      log "wg1".ljust(30),                              emp[:w_g_1].to_s.ljust(30)                            + ( a.nil? || a[:wg1].nil?                              || a[:wg1].class == Hash ?                              '' : a[:wg1] )
      log "wg2".ljust(30),                              emp[:w_g_2].to_s.ljust(30)                            + ( a.nil? || a[:wg2].nil?                              || a[:wg2].class == Hash ?                              '' : a[:wg2] )
      log "wg3".ljust(30),                              emp[:w_g_3].to_s.ljust(30)                            + ( a.nil? || a[:wg3].nil?                              || a[:wg3].class == Hash ?                              '' : a[:wg3] )
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
      log "wg_eff_date".ljust(30),                      emp[:w_g_eff_date].to_s.ljust(30)                     + ( a.nil? || a[:wg_eff_date].nil?                      || a[:wg_eff_date].class == Hash ?                      '' : a[:wg_eff_date] )
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
      log "email".ljust(30),                            emp[:e_m_a_i_l].to_s.ljust(50)                        + ( a.nil? || a[:email].nil?                            || a[:email].class == Hash ?                            '' : a[:email] )
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
