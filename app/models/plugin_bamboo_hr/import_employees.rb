module PluginBambooHr

  class ImportEmployees 
    include ApplicationHelper

    attr_accessor :user_id, :settings, :lastrun
    def initialize user_id,  settings,  lastrun
      @user_id = user_id
      @settings = settings
      @lastrun = lastrun
    end
    
    def perform
      log "\n\nasync method", __method__, 0
      begin

        log 'settings', @settings
        log 'lastrun', @lastrun

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

        # Download locations from AoD
        progress 17, 'Downloading locations from AoD'
        response = aod.call(
          :get_workgroups, message: {
            wGLevel: 1,
            wGSortingOption: 'wgsCode' })  
        locations = response.body[:t_ae_workgroup]

        # Download departments from AoD
        progress 19, 'Downloading departments from AoD'
        response = aod.call(
          :get_workgroups, message: {
            wGLevel: 2,
            wGSortingOption: 'wgsCode' })  
        departments = response.body[:t_ae_workgroup]

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

          progress 21 + (79 * i / emps_changed.count), "Exporting #{ i } of #{ emps_changed.count }"
          log "Exporting emp", "#{ i } of #{ emps_changed.count }"

          # Get employee info
          b = bamboo.get_employee(emp_changed["id"].to_i, 
            "lastName,firstName,middleName,employeeNumber,customBadge,status,hireDate,location,department,payRate,payRateEffectiveDate,payType,customPayClass,customHourlyStatus,dateOfBirth,address1,address2,city,state,zipCode,customFtePercent,bestEmail")

          # ### DEBUG - Get a test employee from BambooHR ###
          # b = bamboo.get_employee(40408, 
          #   "lastName,firstName,middleName,employeeNumber,customBadge,status,hireDate,location,department,payRate,payRateEffectiveDate,payType,customPayClass,customHourlyStatus,dateOfBirth,address1,address2,city,state,zipCode,customFtePercent,bestEmail")
          # b["employeeNumber"] = 1000
          # b["firstName"] = 'Test'
          # b["lastName"] = 'Employee'
          # b["customBadge"] = 0
          # b["ssn"] = '123456789'
          # ### END DEBUG ###

          emp = {

            # AoD field                   Bamboo field (or default)
            lastName:                     b["lastName"],
            firstName:                    b["firstName"],
            initial:                      b["middleName"],
            empID:                        b["employeeNumber"],
            sSN:                          '',
            badge:                        b["customBadge"],
            activeStatus:                 b["status"],
            dateOfHire:                   b["hireDate"],
            wG1:                          3, 
            wG2:                          3, 
            wG3:                          1, 
            currentRate:                  b["payRate"],
            currentRateEffDate:           b["payRateEffectiveDate"],
            activeStatusConditionID:      0,
            inactiveStatusConditionID:    0,
            activeStatusConditionEffDate: now,
            payTypeID:                    b["payType"],
            payTypeEffDate:               now,
            payClassID:                   b["customPayClass"],
            payClassEffDate:              now,
            schPatternID:                 0,
            schPatternEffDate:            now,
            hourlyStatusID:               b["customHourlyStatus"],
            hourlyStatusEffDate:          now,
            avgWeeklyHrs:                 0,
            clockGroupID:                 0,
            birthDate:                    b["dateOfBirth"],
            wGEffDate:                    now,
            phone1:                       '',
            phone2:                       '',
            emergencyContact:             '',
            address1:                     b["address1"],
            address2:                     b["address2"],
            address3:                     '',
            addressCity:                  b["city"],
            addressStateProv:             b["state"],
            addressZIPPC:                 b["zipCode"],
            unionCode:                    '',
            staticCustom1:                b["customFtePercent"],
            staticCustom2:                '',
            staticCustom3:                '',
            staticCustom4:                '',
            staticCustom5:                '',
            staticCustom6:                '',
            eMail:                        b["bestEmail"],
          }

          # EmpID - Pad left 6 zeros
          emp[:empID] = emp[:empID].rjust(6, '0')

          # Middle Name - Get first char
          emp[:initial] = emp[:initial][0].upcase if emp[:initial].present?

          # # SSN - Remove dashes
          # emp[:sSN].gsub!('-', '') if emp[:sSN].present?

          # Email - Downcase
          emp[:eMail].downcase! if emp[:eMail].present? 

          # Active Status - translate
          if emp[:activeStatus] == "Active"
            emp[:activeStatus] = 0
          else
            emp[:activeStatus] = 1
          end

          # Pay Rate - strip currency suffix; cast to float
          emp[:currentRate] = emp[:currentRate].gsub(/[^\d\.]/, '').to_f

          # Pay Type - translate
          if emp[:payTypeID] == "Salary"
            emp[:payTypeID] = 1
            emp[:currentRate] /= 26.0
          else
            emp[:payTypeID] = 0
          end

          # Pay Class - extract num from name
          /\d+/.match(emp[:payClassID]) do |m|
            emp[:payClassID] = m[0].to_i
          end

          # Hourly Status - extract num from name
          /\d+/.match(emp[:hourlyStatusID]) do |m|
            emp[:hourlyStatusID] = m[0].to_i
          end

          # Location - lookup mapping
          locations.each do |this|
            if this[:wg_code] == b["location"]
              emp[:wG1] = this[:wg_num].to_i
            end
          end

          # Department - lookup mapping
          departments.each do |this|
            /\d+/.match(b["department"]) do |m| # Extract dept code from name
              if this[:wg_code] == m[0]
                emp[:wG2] = this[:wg_num].to_i
              end
            end
          end

          # AoD wants a full employee record
          # So fill in the defaults with current values (if emp is found)
          a = nil
          begin
            response = aod.call(
              :get_employee_detail2_by_id_num, message: {
                iDNum: emp[:empID] })  
            a = response.body[:t_ae_employee_detail2]

            # Emp exists in AoD, get current values 
            emp[:wG3]                          = a[:wg3].to_i
            emp[:activeStatusConditionID]      = a[:active_status_condition_id].to_i
            emp[:inactiveStatusConditionID]    = a[:inactive_status_condition_id].to_i
            emp[:activeStatusConditionEffDate] = a[:active_status_condition_eff_date].to_datetime.strftime("%Y-%m-%d")
            emp[:schPatternID]                 = a[:sch_pattern_id].to_i
            emp[:schPatternEffDate]            = a[:sch_pattern_eff_date].to_datetime.strftime("%Y-%m-%d")
            emp[:avgWeeklyHrs]                 = a[:avg_weekly_hrs].to_i
            emp[:clockGroupID]                 = a[:clock_group_id].to_i
            emp[:phone1]                       = a[:phone1]            unless a[:phone1].class            == Hash
            emp[:phone2]                       = a[:phone2]            unless a[:phone2].class            == Hash
            emp[:emergencyContact]             = a[:emergency_contact] unless a[:emergency_contact].class == Hash
            emp[:address3]                     = a[:address3]          unless a[:address3].class          == Hash
            emp[:unionCode]                    = a[:union_code]        unless a[:union_code].class        == Hash
            emp[:staticCustom1]                = a[:static_custom1]    unless a[:static_custom1].class    == Hash || emp[:staticCustom1].present?
            emp[:staticCustom2]                = a[:static_custom2]    unless a[:static_custom2].class    == Hash
            emp[:staticCustom3]                = a[:static_custom3]    unless a[:static_custom3].class    == Hash
            emp[:staticCustom4]                = a[:static_custom4]    unless a[:static_custom4].class    == Hash
            emp[:staticCustom5]                = a[:static_custom5]    unless a[:static_custom5].class    == Hash
            emp[:staticCustom6]                = a[:static_custom6]    unless a[:static_custom6].class    == Hash
          rescue
            # Emp does not exist in AoD, must be new
          end

          # If the employee is about to be terminated
          if emp[:activeStatus] == 1 
            # Assign them an appropriate Inactive Status Condition
            emp[:inactiveStatusConditionID] = 1
          end

          # Send emp to AoD
          debug_import(emp, a)
          response = aod.call(:maintain_employee_detail2, 
            message: {
              aeEmployeeDetail2: emp,
              aeEmpMode:      "aemAuto",
              tBadgeManagement: "bmAuto",
          })
          success = response.body[:maintain_employee_detail2_response][:return]
        end

      rescue Exception => exc
        log 'exception', exc.message
        log 'exception backtrace', exc.backtrace
      ensure
        progress 100, ''
      end
    end

    private

    def debug_import(emp, a)
      log "FIELD NAME".ljust(30),                   "WHAT WOULD BE IMPORTED".ljust(30)                + "WHATS IN AOD RIGHT NOW"
      log "lastName".ljust(30),                     emp[:lastName].to_s.ljust(30)                     + ( a.nil? || a[:last_name].nil?                        || a[:last_name].class == Hash ?                        '' : a[:last_name] )
      log "firstName".ljust(30),                    emp[:firstName].to_s.ljust(30)                    + ( a.nil? || a[:first_name].nil?                       || a[:first_name].class == Hash ?                       '' : a[:first_name] )
      log "initial".ljust(30),                      emp[:initial].to_s.ljust(30)                      + ( a.nil? || a[:initial].nil?                          || a[:initial].class == Hash ?                          '' : a[:initial] )
      log "empID".ljust(30),                        emp[:empID].to_s.ljust(30)                        + ( a.nil? || a[:emp_id].nil?                           || a[:emp_id].class == Hash ?                           '' : a[:emp_id] )
      log "sSN".ljust(30),                          emp[:sSN].to_s.ljust(30)                          + ( a.nil? || a[:ssn].nil?                              || a[:ssn].class == Hash ?                              '' : a[:ssn] )
      log "badge".ljust(30),                        emp[:badge].to_s.ljust(30)                        + ( a.nil? || a[:badge].nil?                            || a[:badge].class == Hash ?                            '' : a[:badge] )
      log "activeStatus".ljust(30),                 emp[:activeStatus].to_s.ljust(30)                 + ( a.nil? || a[:active_status].nil?                    || a[:active_status].class == Hash ?                    '' : a[:active_status] )
      log "dateOfHire".ljust(30),                   emp[:dateOfHire].to_s.ljust(30)                   + ( a.nil? || a[:date_of_hire].nil?                     || a[:date_of_hire].class == Hash ?                     '' : a[:date_of_hire] )
      log "wG1".ljust(30),                          emp[:wG1].to_s.ljust(30)                          + ( a.nil? || a[:wg1].nil?                              || a[:wg1].class == Hash ?                              '' : a[:wg1] )
      log "wG2".ljust(30),                          emp[:wG2].to_s.ljust(30)                          + ( a.nil? || a[:wg2].nil?                              || a[:wg2].class == Hash ?                              '' : a[:wg2] )
      log "wG3".ljust(30),                          emp[:wG3].to_s.ljust(30)                          + ( a.nil? || a[:wg3].nil?                              || a[:wg3].class == Hash ?                              '' : a[:wg3] )
      log "currentRate".ljust(30),                  emp[:currentRate].to_s.ljust(30)                  + ( a.nil? || a[:current_rate].nil?                     || a[:current_rate].class == Hash ?                     '' : a[:current_rate] )
      log "currentRateEffDate".ljust(30),           emp[:currentRateEffDate].to_s.ljust(30)           + ( a.nil? || a[:current_rate_eff_date].nil?            || a[:current_rate_eff_date].class == Hash ?            '' : a[:current_rate_eff_date] )
      log "activeStatusConditionID".ljust(30),      emp[:activeStatusConditionID].to_s.ljust(30)      + ( a.nil? || a[:active_status_condition_id].nil?       || a[:active_status_condition_id].class == Hash ?       '' : a[:active_status_condition_id] )
      log "inactiveStatusConditionID".ljust(30),    emp[:inactiveStatusConditionID].to_s.ljust(30)    + ( a.nil? || a[:inactive_status_condition_id].nil?     || a[:inactive_status_condition_id].class == Hash ?     '' : a[:inactive_status_condition_id] )
      log "activeStatusConditionEffDate".ljust(30), emp[:activeStatusConditionEffDate].to_s.ljust(30) + ( a.nil? || a[:active_status_condition_eff_date].nil? || a[:active_status_condition_eff_date].class == Hash ? '' : a[:active_status_condition_eff_date] )
      log "payTypeID".ljust(30),                    emp[:payTypeID].to_s.ljust(30)                    + ( a.nil? || a[:pay_type_id].nil?                      || a[:pay_type_id].class == Hash ?                      '' : a[:pay_type_id] )
      log "payTypeEffDate".ljust(30),               emp[:payTypeEffDate].to_s.ljust(30)               + ( a.nil? || a[:pay_type_eff_date].nil?                || a[:pay_type_eff_date].class == Hash ?                '' : a[:pay_type_eff_date] )
      log "payClassID".ljust(30),                   emp[:payClassID].to_s.ljust(30)                   + ( a.nil? || a[:pay_class_id].nil?                     || a[:pay_class_id].class == Hash ?                     '' : a[:pay_class_id] )
      log "payClassEffDate".ljust(30),              emp[:payClassEffDate].to_s.ljust(30)              + ( a.nil? || a[:pay_class_eff_date].nil?               || a[:pay_class_eff_date].class == Hash ?               '' : a[:pay_class_eff_date] )
      log "schPatternID".ljust(30),                 emp[:schPatternID].to_s.ljust(30)                 + ( a.nil? || a[:sch_pattern_id].nil?                   || a[:sch_pattern_id].class == Hash ?                   '' : a[:sch_pattern_id] )
      log "schPatternEffDate".ljust(30),            emp[:schPatternEffDate].to_s.ljust(30)            + ( a.nil? || a[:sch_pattern_eff_date].nil?             || a[:sch_pattern_eff_date].class == Hash ?             '' : a[:sch_pattern_eff_date] )
      log "hourlyStatusID".ljust(30),               emp[:hourlyStatusID].to_s.ljust(30)               + ( a.nil? || a[:hourly_status_id].nil?                 || a[:hourly_status_id].class == Hash ?                 '' : a[:hourly_status_id] )
      log "hourlyStatusEffDate".ljust(30),          emp[:hourlyStatusEffDate].to_s.ljust(30)          + ( a.nil? || a[:hourly_status_eff_date].nil?           || a[:hourly_status_eff_date].class == Hash ?           '' : a[:hourly_status_eff_date] )
      log "avgWeeklyHrs".ljust(30),                 emp[:avgWeeklyHrs].to_s.ljust(30)                 + ( a.nil? || a[:avg_weekly_hrs].nil?                   || a[:avg_weekly_hrs].class == Hash ?                   '' : a[:avg_weekly_hrs] )
      log "clockGroupID".ljust(30),                 emp[:clockGroupID].to_s.ljust(30)                 + ( a.nil? || a[:clock_group_id].nil?                   || a[:clock_group_id].class == Hash ?                   '' : a[:clock_group_id] )
      log "birthDate".ljust(30),                    emp[:birthDate].to_s.ljust(30)                    + ( a.nil? || a[:birth_date].nil?                       || a[:birth_date].class == Hash ?                       '' : a[:birth_date] )
      log "wGEffDate".ljust(30),                    emp[:wGEffDate].to_s.ljust(30)                    + ( a.nil? || a[:wg_eff_date].nil?                      || a[:wg_eff_date].class == Hash ?                      '' : a[:wg_eff_date] )
      log "phone1".ljust(30),                       emp[:phone1].to_s.ljust(30)                       + ( a.nil? || a[:phone1].nil?                           || a[:phone1].class == Hash ?                           '' : a[:phone1] )
      log "phone2".ljust(30),                       emp[:phone2].to_s.ljust(30)                       + ( a.nil? || a[:phone2].nil?                           || a[:phone2].class == Hash ?                           '' : a[:phone2] )
      log "emergencyContact".ljust(30),             emp[:emergencyContact].to_s.ljust(30)             + ( a.nil? || a[:emergency_contact].nil?                || a[:emergency_contact].class == Hash ?                '' : a[:emergency_contact] )
      log "address1".ljust(30),                     emp[:address1].to_s.ljust(30)                     + ( a.nil? || a[:address1].nil?                         || a[:address1].class == Hash ?                         '' : a[:address1] )
      log "address2".ljust(30),                     emp[:address2].to_s.ljust(30)                     + ( a.nil? || a[:address2].nil?                         || a[:address2].class == Hash ?                         '' : a[:address2] )
      log "address3".ljust(30),                     emp[:address3].to_s.ljust(30)                     + ( a.nil? || a[:address3].nil?                         || a[:address3].class == Hash ?                         '' : a[:address3] )
      log "addressCity".ljust(30),                  emp[:addressCity].to_s.ljust(30)                  + ( a.nil? || a[:address_city].nil?                     || a[:address_city].class == Hash ?                     '' : a[:address_city] )
      log "addressStateProv".ljust(30),             emp[:addressStateProv].to_s.ljust(30)             + ( a.nil? || a[:address_state_prov].nil?               || a[:address_state_prov].class == Hash ?               '' : a[:address_state_prov] )
      log "addressZIPPC".ljust(30),                 emp[:addressZIPPC].to_s.ljust(30)                 + ( a.nil? || a[:address_zippc].nil?                    || a[:address_zippc].class == Hash ?                    '' : a[:address_zippc] )
      log "unionCode".ljust(30),                    emp[:unionCode].to_s.ljust(30)                    + ( a.nil? || a[:union_code].nil?                       || a[:union_code].class == Hash ?                       '' : a[:union_code] )
      log "staticCustom1".ljust(30),                emp[:staticCustom1].to_s.ljust(30)                + ( a.nil? || a[:static_custom1].nil?                   || a[:static_custom1].class == Hash ?                   '' : a[:static_custom1] )
      log "staticCustom2".ljust(30),                emp[:staticCustom2].to_s.ljust(30)                + ( a.nil? || a[:static_custom2].nil?                   || a[:static_custom2].class == Hash ?                   '' : a[:static_custom2] )
      log "staticCustom3".ljust(30),                emp[:staticCustom3].to_s.ljust(30)                + ( a.nil? || a[:static_custom3].nil?                   || a[:static_custom3].class == Hash ?                   '' : a[:static_custom3] )
      log "staticCustom4".ljust(30),                emp[:staticCustom4].to_s.ljust(30)                + ( a.nil? || a[:static_custom4].nil?                   || a[:static_custom4].class == Hash ?                   '' : a[:static_custom4] )
      log "staticCustom5".ljust(30),                emp[:staticCustom5].to_s.ljust(30)                + ( a.nil? || a[:static_custom5].nil?                   || a[:static_custom5].class == Hash ?                   '' : a[:static_custom5] )
      log "staticCustom6".ljust(30),                emp[:staticCustom6].to_s.ljust(30)                + ( a.nil? || a[:static_custom6].nil?                   || a[:static_custom6].class == Hash ?                   '' : a[:static_custom6] )
      log "eMail".ljust(30),                        emp[:eMail].to_s.ljust(50)                        + ( a.nil? || a[:email].nil?                            || a[:email].class == Hash ?                            '' : a[:email] )
    end

    def progress(percent, status)
      cache_save @user_id, 'bhr_progress', percent.to_s
      cache_save @user_id, 'bhr_status', status
    end

  end
end
