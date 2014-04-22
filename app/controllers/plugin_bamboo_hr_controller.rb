class PluginBambooHrController < ApplicationController
  before_filter :authenticate_user!
  layout "plugin"  

  @@plugin_id = 5

  def index
    begin
      log "\n\nmethod", __method__, 0

      # Get plugin settings for this user
      session[:settings] ||= get_settings(PluginBambooHr::Settings, 
        current_user.id, 
        current_user.customer_id, 
        @@plugin_id)

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def settings
  end

  def save_settings
  end
 
  def import_employees
    begin
      log "\n\nmethod", __method__, 0

      # Connect to AoD
      aod = create_conn(session[:settings])

      # Download locations from AoD
      response = aod.call(
        :get_workgroups, message: {
          wGLevel: 1,
          wGSortingOption: 'wgsCode' })  
      locations = response.body[:t_ae_workgroup]

      # Download departments from AoD
      response = aod.call(
        :get_workgroups, message: {
          wGLevel: 2,
          wGSortingOption: 'wgsCode' })  
      departments = response.body[:t_ae_workgroup]
      
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

      # Get all employees changed since a certain date (selected by the user)
      if params[:lastrun] == "0"      # Last Week
        since = 1.week.ago.iso8601
      elsif params[:lastrun] == "1"   # Last Month
        since = 1.month.ago.iso8601
      else                            # Last Year
        since = 1.year.ago.iso8601
      end
      bamboo = PluginBambooHr::Bamboo.new(
        session[:settings].bamboo_company,
        session[:settings].bamboo_key)
      # emps_changed = bamboo.get_employees_changed(since)

      # # For each changed emp
      # emps_changed.each_with_index do |emp_changed, i|

        # # Get employee info
        # emp = bamboo.get_employee(emp_changed["id"].to_i, 
        #   "lastName,firstName,middleName,employeeNumber,ssn,customBadge,status,hireDate,location,department,payRate,payRateEffectiveDate,payType,customPayClass,customHourlyStatus,dateOfBirth,address1,address2,city,state,zipCode,customFTE,bestEmail")

        ### DEBUG ###
        # Get a test employee from BambooHR
        emp = bamboo.get_employee(40408, 
          "lastName,firstName,middleName,employeeNumber,ssn,customBadge,status,hireDate,location,department,payRate,payRateEffectiveDate,payType,customPayClass,customHourlyStatus,dateOfBirth,address1,address2,city,state,zipCode,customFTE,bestEmail")
        log 'emp', emp

        # Edit their data for the test
        emp["employeeNumber"] = 1000
        emp["firstName"] = 'Test'
        emp["lastName"] = 'Employee'
        ### END DEBUG ###

        # Get their values
        lastname             = emp["lastName"]
        firstname            = emp["firstName"]
        middlename           = emp["middleName"]
        employeenumber       = emp["employeeNumber"]
        ssn                  = emp["ssn"]
        custombadge          = emp["customBadge"]
        status               = emp["status"]
        hiredate             = emp["hireDate"]
        payrate              = emp["payRate"]
        payrateeffectivedate = emp["payRateEffectiveDate"]
        paytype              = emp["payType"]
        dateofbirth          = emp["dateOfBirth"]
        address1             = emp["address1"]
        address2             = emp["address2"]
        city                 = emp["city"]
        state                = emp["state"]
        zipcode              = emp["zipCode"]
        customfte            = emp["customFTE"]
        bestemail            = emp["bestEmail"]

        # Employee Number - Pad left 6 zeros
        employeenumber = sprintf("%06d", employeenumber)

        # Active Status - translate
        if status == "Active"
          status = 0
        else
          status = 1
        end

        # Pay Type - translate
        if paytype == "Salary"
          paytype = 1
        else
          paytype = 0
        end

        # Pay Class - extract num from name
        payclass = 0
        /\d+/.match(emp["customPayClass"]) do |m|
          payclass = m[0].to_i
        end

        # Hourly Status - extract num from name
        hourlystatus = 0
        /\d+/.match(emp["customHourlyStatus"]) do |m|
          hourlystatus = m[0].to_i
        end

        # Pay Rate - strip currency suffix; cast to float
        payrate = payrate.gsub(/[^\d\.]/, '').to_f 

        # Pay Rate - divide by 26 if salary (biweekly rate)
        payrate /= 26.0 if paytype == 1

        # Location - lookup mapping
        location = 0
        locations.each do |this|
          if this[:wg_code] == emp["location"]
            location = this[:wg_num].to_i
          end
        end

        # Department - lookup mapping
        department = 0
        departments.each do |this|
          /\d+/.match(emp[department]) do |m| # Extract dept code from name
            if this[:wg_code] == m[0]
              department = this[:wg_num].to_i
            end
          end
        end

        # Prepare to send emp to AoD
        aod_emp = {
              
          # AoD field             # Bamboo field
          # --------------------------------------

          # employeeName:
          lastName:               lastname,
          firstName:              firstname,
          initial:                middlename,
          empID:                  employeenumber,
          sSN:                    ssn,
          badge:                  custombadge,
          # filekey:
          activeStatus:           status,
          dateOfHire:             hiredate,    
          wG1:                    location,
          wG2:                    department,
          # wG3:
          # wGDescr:
          currentRate:            payrate,
          currentRateEffDate:     payrateeffectivedate,
          # activeStatusConditionID:
          # inactiveStatusConditionID:
          # activeStatusConditionEffDate:
          payTypeID:              paytype,
          # payTypeEffDate:
          payClassID:             payclass,
          # payClassEffDate:
          # schPatternID:
          # schPatternEffDate:
          hourlyStatusID:         hourlystatus,
          # hourlyStatusEffDate:
          # avgWeeklyHrs:
          # clockGroupID:
          birthDate:              dateofbirth,
          # wGEffDate:
          # phone1:
          # phone2:
          # emergencyContact:
          address1:               address1,
          address2:               address2,
          # address3:
          addressCity:            city,
          addressStateProv:       state,
          addressZIPPC:           zipcode,
          # unionCode:
          staticCustom1:          customfte,
          # staticCustom2:
          # staticCustom3:
          # staticCustom4:
          # staticCustom5:
          # staticCustom6:
          eMail:                  bestemail,
        }

        log 'aod emp', aod_emp

        # # Send emp to AoD
        # response = aod.call(:maintain_employee_detail_2, 
        #   message: {
        #     aeEmployeeDetail2: aod_emp,
        #     aeEmpMode:      "aemAuto",
        #     tBadgeManagement: "bmAuto",
        # })

      # end

      # cache_save current_user.id, 'bhr_status', 'Initializing'
      # cache_save current_user.id, 'bhr_progress', '10'
      # sleep 1

      # # Request employees from AoD, in the background
      # Delayed::Job.enqueue PluginBambooHr::ImportEmployees.new(
      #   current_user.id,
      #   session[:settings],
      #   params[:lastrun])
      
      render json: true

    rescue Exception => exc
      log 'exception', exc.message
      log 'exception backtrace', exc.backtrace
    end
  end

  def progress
    progress = cache_get current_user.id, 'bhr_progress'
    status   = cache_get current_user.id, 'bhr_status'

    progress ||= 0
    status   ||= ''

    render json: { progress: progress, status: status }.to_json
  end

end
