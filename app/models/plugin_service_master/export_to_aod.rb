module PluginServiceMaster

  class ExportToAod 
    include ApplicationHelper

    attr_accessor :user_id, :settings, :scheds
    def initialize user_id,  settings,  scheds
      @user_id = user_id
      @settings = settings
      @scheds = scheds
    end
    
    def perform
      log "\n\nasync method", __method__, 0
      begin

        # Connect to AoD
        progress 20, 'Connecting to AoD'
        aod = create_conn(@settings)

        # Send scheds to AoD one at a time
        scheds.each_with_index do |sched, i|

          progress 20 + (80 * i / scheds.count), "Exporting #{ i } of #{ scheds.count }"

          # Fix null values
          fix_nulls sched

          # Send schedule to AoD
          log "Exporting sched", "#{ i } of #{ scheds.count }"
          log "sched", sched
          response = aod.call(:append_employee_schedule_by_filekey, 
            message: {
              filekey:        sched.filekey,
              aeSchedule: {
                schDate:      sched.sch_date,
                schStartTime: sched.sch_start_time,
                schEndTime:   sched.sch_end_time,
                schHours:     sched.sch_hours,
                schRate:      sched.sch_rate,
                schHoursHund: sched.sch_hours_hund,
                schType:      sched.sch_type,
                schStyle:     sched.sch_style,
                schPattID:    sched.sch_patt_id,
                benefitID:    sched.benefit_id,
                payDesID:     sched.pay_des_id,
                schWG1:       sched.sch_wg1,
                schWG2:       sched.sch_wg2,
                schWG3:       sched.sch_wg3,
                schWG4:       sched.sch_wg4,
                schWG5:       sched.sch_wg5,
                schWG6:       sched.sch_wg6,
                schWG7:       sched.sch_wg7,
                schWGDescr:   "",
              }
            })

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
      # Get this employee from the db
      emp = PsvmEmp.where(filekey: sched.filekey).first
      sched.sch_hours ||= 0
      sched.sch_rate ||= 0
      sched.sch_hours_hund ||= 0
      sched.sch_type ||= 1
      sched.sch_style ||= 0
      sched.sch_patt_id ||= 1
      sched.benefit_id ||= 1
      sched.pay_des_id ||= 1
      sched.sch_wg1 = emp.wg1 if sched.sch_wg1.nil? || sched.sch_wg1 == 0
      sched.sch_wg2 = emp.wg2 if sched.sch_wg2.nil? || sched.sch_wg2 == 0
      sched.sch_wg3 = emp.wg3 if sched.sch_wg3.nil? || sched.sch_wg3 == 0
      sched.sch_wg4 = emp.wg4 if sched.sch_wg4.nil? || sched.sch_wg4 == 0
      sched.sch_wg5 = emp.wg5 if sched.sch_wg5.nil? || sched.sch_wg5 == 0
      sched.sch_wg6 = emp.wg6 if sched.sch_wg6.nil? || sched.sch_wg6 == 0
      sched.sch_wg7 = emp.wg7 if sched.sch_wg7.nil? || sched.sch_wg7 == 0
      sched.sch_wg1 = 1 if sched.sch_wg1 == 0
      sched.sch_wg2 = 1 if sched.sch_wg2 == 0
      sched.sch_wg3 = 1 if sched.sch_wg3 == 0
      sched.sch_wg4 = 1 if sched.sch_wg4 == 0
      sched.sch_wg5 = 1 if sched.sch_wg5 == 0
      sched.sch_wg6 = 1 if sched.sch_wg6 == 0
      sched.sch_wg7 = 1 if sched.sch_wg7 == 0
    end

    def progress percent, status
      cache_save @user_id, 'svm_export_scheds_progress', percent.to_s
      cache_save @user_id, 'svm_export_scheds_status', status
      sleep 2 # Wait to allow user to see status
    end

  end
end
