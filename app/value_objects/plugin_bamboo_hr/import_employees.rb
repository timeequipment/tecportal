module PluginBambooHr

  class ImportEmployees 
    include ApplicationHelper
    # basic_auth '6f1cb6f7e488b8f8060f8225873816b85c513491', 'x'

    # Uncomment to output entire HTTP request and response
    # debug_output $stdout

    attr_accessor :user_id, :settings, :lastrun
    def initialize user_id,  settings,  lastrun
      @user_id = user_id
      @settings = settings
      @lastrun = lastrun
    end
    
    def perform
      log "\n\nasync method", __method__, 0
      begin

        log 'settings', settings

        # Get employees from BambooHR
        progress 20, 'Getting employees from BambooHR'
        bamboo = PluginBambooHr::Bamboo.new(
          settings.bamboo_company,
          settings.bamboo_key)
        emps = bamboo.employee_list

        # Connect to AoD
        progress 30, 'Connecting to AoD'
        aod = create_conn(@settings)

        # Send emps to AoD one at a time
        emps.each_with_index do |emp, i|

    #       progress 30 + (70 * i / emps.count), "Exporting #{ i } of #{ emps.count }"
    #       log "Exporting emp", "#{ i } of #{ emps.count }"

    #       # Fix null values
    #       fix_nulls emp

    # #             "id" => "40410",
    # #    "displayName" => "Andrea Aragon",
    # #      "firstName" => "Andrea",
    # #       "lastName" => "Aragon",
    # #       "jobTitle" => "Clinical Specialist II",
    # #      "workEmail" => "Andrea.Aragon@protocallservices.com",
    # #     "department" => "PCW Clinicians",
    # #       "location" => "Portland",
    # #  "photoUploaded" => true,
    # #       "photoUrl" => "https://9edf159ac8bc0103f4ce-e73894f4f53a19fbfc0548cd63ea8820.ssl.cf1.rackcdn.com/photos/40410-1-1.jpg",
    # # "canUploadPhoto" => 1


    #       # Send emp to AoD
    #       response = aod.call(:maintain_employee_basic, 
    #         message: {
    #           aeEmployeeBasic: {
    #             #employeeName: '',
    #             lastName:     "TestLastName",
    #             firstName:    "TestFirstName",
    #             #initial:      asdf,
    #             empID:        "001000",
    #             # sSN:          "",
    #             # badge:        "",
    #             #filekey:      asdf,
    #             activeStatus: 0,
    #             #dateOfHire:   asdf,
    #             wG1:          0,
    #             wG2:          0,
    #             wG3:          0,
    #             #wGDescr:      "" 
    #             },
    #           aeEmpMode:      "aemAuto",
    #           badgeManagement: "bmAuto"
    #         })

    #       success = response.body[:maintain_employee_basic_response][:return]


    #       # # Send emp to AoD
    #       # response = aod.call(:maintain_employee_basic, 
    #       #   message: {
    #       #     aeEmployeeBasic: {
    #       #       #employeeName: '',
    #       #       lastName:     emp["lastName"],
    #       #       firstName:    emp["firstName"],
    #       #       #initial:      asdf,
    #       #       empID:        emp["id"],
    #       #       sSN:          "",
    #       #       badge:        "",
    #       #       #filekey:      asdf,
    #       #       activeStatus: 0,
    #       #       #dateOfHire:   asdf,
    #       #       wG1:          0,
    #       #       wG2:          0,
    #       #       wG3:          0,
    #       #       #wGDescr:      "" 
    #       #       },
    #       #     aeEmpMode:      "aemAuto",
    #       #     tBadgeManagement: "bmAuto"
    #       #   })

        log 'settings', @settings
        log 'lastrun', @lastrun

        end
      rescue Exception => exc
        log 'exception', exc.message
        log 'exception backtrace', exc.backtrace
      ensure
        progress 100, ''
      end
    end

    private

    def fix_nulls(sched)
      # sched.sch_hours ||= 0
      # sched.sch_rate ||= 0
      # sched.sch_hours_hund ||= 0
      # sched.sch_type ||= 1
      # sched.sch_style ||= 0
      # sched.sch_patt_id ||= 1
      # sched.benefit_id ||= 1
      # sched.pay_des_id ||= 1
      # sched.sch_wg1 = emp.wg1 if sched.sch_wg1.nil? || sched.sch_wg1 == 0
      # sched.sch_wg2 = emp.wg2 if sched.sch_wg2.nil? || sched.sch_wg2 == 0
      # sched.sch_wg3 = emp.wg3 if sched.sch_wg3.nil? || sched.sch_wg3 == 0
      # sched.sch_wg4 = emp.wg4 if sched.sch_wg4.nil? || sched.sch_wg4 == 0
      # sched.sch_wg5 = emp.wg5 if sched.sch_wg5.nil? || sched.sch_wg5 == 0
      # sched.sch_wg6 = emp.wg6 if sched.sch_wg6.nil? || sched.sch_wg6 == 0
      # sched.sch_wg7 = emp.wg7 if sched.sch_wg7.nil? || sched.sch_wg7 == 0
      # sched.sch_wg1 = 1 if sched.sch_wg1 == 0
      # sched.sch_wg2 = 1 if sched.sch_wg2 == 0
      # sched.sch_wg3 = 1 if sched.sch_wg3 == 0
      # sched.sch_wg4 = 1 if sched.sch_wg4 == 0
      # sched.sch_wg5 = 1 if sched.sch_wg5 == 0
      # sched.sch_wg6 = 1 if sched.sch_wg6 == 0
      # sched.sch_wg7 = 1 if sched.sch_wg7 == 0
    end

    def progress(percent, status)
      cache_save @user_id, 'bhr_progress', percent.to_s
      cache_save @user_id, 'bhr_status', status
    end

  end
end
