module PluginServiceMaster

  class ExportToAod
    include ApplicationHelper

    attr_accessor :user_id, :settings, :start_date, :end_date, :scheds
    def initialize user_id,  settings,  start_date,  end_date,  scheds
      @user_id = user_id
      @settings = settings
      @start_date = start_date
      @end_date = end_date
      @scheds = scheds
    end

    def perform
      log "\n\nasync method", __method__, 0
      begin

        # Connect to AoD
        progress 20, 'Connecting to AoD'
        aod = create_conn(@settings)

        # Get the unique filekeys we're exporting scheds for
        filekeys = @scheds.
          uniq {|sched| sched.filekey}.
          map  {|sched| sched.filekey}

        log 'employees count', filekeys.count
        log 'scheds count', @scheds.count

        # For each filekey
        filekeys.each_with_index do |filekey, i|

          # Remove scheds in AoD for this filekey, for this date range
          x = i + 1
          y = filekeys.count
          p = "Removing old schedules for employee #{ x } of #{ y }"
          progress 20 + (20 * x / y), p
          log 'progress', p

          response = aod.call(:remove_employee_schedules_in_range_by_filekey,
            message: {
              filekey:        filekey,
              tDateRangeEnum: 'drCustom',
              minDate:        @start_date,
              maxDate:        @end_date
            })
        end

        # Send scheds to AoD one at a time
        @scheds.each_with_index do |sched, i|

          x = i + 1
          y = @scheds.count
          p = "Exporting schedule #{ x } of #{ y }"
          progress 40 + (60 * x / y), p
          log 'progress', p

          # Fix null values
          fix_nulls sched

          # Send schedule to AoD
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
                schWG1:       sched.sch_wg1,
                schWG2:       sched.sch_wg2,
                schWG3:       sched.sch_wg3,
                schWG4:       sched.sch_wg4,
                schWG5:       sched.sch_wg5,
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
      # Get this employee from the db, for default values
      emp = PsvmEmp.where(filekey: sched.filekey).first
      sched.sch_hours ||= 0
      sched.sch_rate ||= 0
      sched.sch_hours_hund ||= 0
      sched.sch_wg1 = emp.wg1 if sched.sch_wg1.nil? || sched.sch_wg1 == 0
      sched.sch_wg2 = emp.wg2 if sched.sch_wg2.nil? || sched.sch_wg2 == 0
      sched.sch_wg3 = emp.wg3 if sched.sch_wg3.nil? || sched.sch_wg3 == 0
      sched.sch_wg4 = emp.wg4 if sched.sch_wg4.nil? || sched.sch_wg4 == 0
      sched.sch_wg5 = emp.wg5 if sched.sch_wg5.nil? || sched.sch_wg5 == 0
      sched.sch_wg1 = 1 if sched.sch_wg1 == 0
      sched.sch_wg2 = 1 if sched.sch_wg2 == 0
      sched.sch_wg3 = 1 if sched.sch_wg3 == 0
      sched.sch_wg4 = 1 if sched.sch_wg4 == 0
      sched.sch_wg5 = 1 if sched.sch_wg5 == 0
    end

    def progress percent, status
      cache_save @user_id, 'svm_export_scheds_progress', percent.to_s
      cache_save @user_id, 'svm_export_scheds_status', status
    end

  end
end
