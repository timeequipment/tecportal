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
      
      # Get all employees changed since a certain date (selected by the user)
      if params[:lastrun] == "0"      # Last Week
        since = 1.week.ago.iso8601
      elsif params[:lastrun] == "1"   # Last Month
        since = 1.month.ago.iso8601
      else                            # Last Year
        since = 1.year.ago.iso8601
      end

      log 'params', params
      log 'since', since

      # Here is an example of the correct time format to send to BambooHR, for 'since'
      # 2014-04-06T13:00:00-05:00
      
      # Get the emps from BambooHR
      bamboo = PluginBambooHr::Bamboo.new(
        session[:settings].bamboo_company,
        session[:settings].bamboo_key)
      # emps1 = bamboo.get_employees_changed(since)

# 18:48:53 web.1    |         emps-last-changed: [
# 18:48:53 web.1    |             [  0] {
# 18:48:53 web.1    |                                  "id" => "40408",
# 18:48:53 web.1    |                              "action" => "Updated",
# 18:48:53 web.1    |                         "lastChanged" => "2014-04-18T17:33:24+00:00"
# 18:48:53 web.1    |             },
# 18:48:53 web.1    |             [  1] {
# 18:48:53 web.1    |                                  "id" => "40409",
# 18:48:53 web.1    |                              "action" => "Updated",
# 18:48:53 web.1    |                         "lastChanged" => "2014-04-16T20:11:23+00:00"
# 18:48:53 web.1    |             },
# 18:48:53 web.1    |
# 18:48:54 web.1    |         emps: [
# 18:48:54 web.1    |             [  0] {
# 18:48:54 web.1    |                                     "id" => "40559",
# 18:48:54 web.1    |                            "displayName" => "Karen Abear",
# 18:48:54 web.1    |                              "firstName" => "Karen",
# 18:48:54 web.1    |                               "lastName" => "Abear",
# 18:48:54 web.1    |                               "jobTitle" => "Clinical Specialist II",
# 18:48:54 web.1    |                              "workEmail" => "karen.abear@protocallservices.com",
# 18:48:54 web.1    |                             "department" => "700 - PCSW Clinicians",
# 18:48:54 web.1    |                               "location" => "PCSW",
# 18:48:54 web.1    |                          "photoUploaded" => true,
# 18:48:54 web.1    |                               "photoUrl" => "https://9edf159ac8bc0103f4ce-e73894f4f53a19fbfc0548cd63ea8820.ssl.cf1.rackcdn.com/photos/40559-1-1.jpg",
# 18:48:54 web.1    |                         "canUploadPhoto" => 1
# 18:48:54 web.1    |             },
# 18:48:54 web.1    |             [  1] {
# 18:48:54 web.1    |                                     "id" => "40527",
# 18:48:54 web.1    |                            "displayName" => "Michelle Adamski",
# 18:48:54 web.1    |                              "firstName" => "Michelle",
# 18:48:54 web.1    |                               "lastName" => "Adamski",
# 18:48:54 web.1    |                               "jobTitle" => "Clinical Specialist II",
# 18:48:54 web.1    |                              "workEmail" => "michelle.adamski@protocallservices.com",
# 18:48:54 web.1    |                             "department" => "601 - PCE Clinicians",
# 18:48:54 web.1    |                               "location" => "PCE",
# 18:48:54 web.1    |                          "photoUploaded" => true,
# 18:48:54 web.1    |                               "photoUrl" => "https://9edf159ac8bc0103f4ce-e73894f4f53a19fbfc0548cd63ea8820.ssl.cf1.rackcdn.com/photos/40527-1-1.jpg",
# 18:48:54 web.1    |                         "canUploadPhoto" => 1
# 18:48:54 web.1    |             },

# emp: {
#                     "id" => "40408",
#               "lastName" => "Allen",
#              "firstName" => "Timothy",
#             "middleName" => "F",
#         "employeeNumber" => "1602",
#                    "ssn" => "378-68-9637",
#              "bestEmail" => "Tim.Allen@protocallservices.com",
#               "address1" => "1955 Manning Ave NW",
#               "address2" => nil,
#                   "city" => "Walker",
#                  "state" => "MI",
#                "zipcode" => "49534",
#                "paytype" => "Salary",
#                "payrate" => "61856.86 USD",
#   "payrateeffectivedate" => "2013-06-07",
#            "customBadge" => "1602"
# }

      # Get a test employee from BambooHR
      emp = bamboo.get_employee(40408, 
        "lastName,firstName,middleName,employeeNumber,ssn,bestEmail,address1,address2,city,state,zipcode,paytype,payrate,payrateeffectivedate,customfte,customBadge,location,department,customPayClass,customHourlyStatus")
      log 'emp', emp

      # Edit their data for the test
      emp["employeeNumber"] = 1000
      emp["firstName"] = 'Testy'
      emp["lastName"] = 'Emploeey'

      # Strip currency suffix from payrate
      payrate = emp["payrate"].gsub(/[^(\d\.)]/, '').to_f 

      # If the paytype is salary
      # Divide it by 26 to get the period pay rate
      payrate /= 26.0 if emp["paytype"] == "Salary"

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

      # Lookup the location we got from Bamboo in AoD
      location = 0
      locations.each do |this|
        if this[:wg_code] == emp["location"]
          location = this[:wg_num].to_i
        end
      end

      # Lookup the department we got from Bamboo in AoD
      department = 0
      departments.each do |this|
        if this[:wg_code] == emp["department"]
          department = this[:wg_num].to_i
        end
      end

      # # Send emp to AoD
      # response = aod.call(:maintain_employee_basic, 
      #   message: {
          log 'aeEmployeeBasic', {
            #employeeName: '',
            lastName:     emp["lastName"],
            firstName:    emp["firstName"],
            initial:      emp["middleName"],
            empID:        sprintf("%06d", emp["employeeNumber"]), # pad left 6 zeros
            sSN:          emp["ssn"],
            badge:        emp["customBadge"],
            #filekey:      asdf,
            activeStatus: 0,
            dateOfHire:   emp["hireDate"],
            wG1:          location,
            wG2:          department,
            #wG3:          0,
            currentRate:  payrate,
            #wGDescr:      "" 
            }
        #     ,
        #   aeEmpMode:      "aemAuto",
        #   tBadgeManagement: "bmAuto"
        # })


=begin Mapping Bamboo to AoD
lastName              lastName
firstName             firstName
middleName            initial
employeeNumber        empID
ssn                   sSN
customBadge           badge
                      filekey
status                activeStatus
hireDate              dateOfHire
location              wG1
department            wG2
                      wG3
                      wGDescr
payRate               currentRate
payRateEffectiveDate  currentRateEffDate
                      activeStatusConditionID
                      inactiveStatusConditionID
                      activeStatusConditionEffDate
payType               payTypeID
                      payTypeEffDate
customPayClass        payClassID
                      payClassEffDate
                      schPatternID
                      schPatternEffDate
customHourlyStatus    hourlyStatusID
                      hourlyStatusEffDate
                      avgWeeklyHrs
                      clockGroupID
dateOfBirth           birthDate
                      wGEffDate
                      phone1
                      phone2
                      emergencyContact
address1              address1
address2              address2
                      address3
city                  addressCity
state                 addressStateProv
zipCode               addressZIPPC
                      unionCode
customFTE%            staticCustom1
                      staticCustom2
                      staticCustom3
                      staticCustom4
                      staticCustom5
                      staticCustom6
bestEmail             eMail
=end

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
