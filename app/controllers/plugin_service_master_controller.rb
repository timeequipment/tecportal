class PluginServiceMasterController < ApplicationController
  before_filter :authenticate_user!
  around_filter :catch_exceptions
  layout "plugin_service_master"

  @@plugin_id = 4

  def schedules
    log __method__

    # Get plugin settings for this user
    cls = PluginServiceMaster::Settings
    if session[:settings].class != cls
       session[:settings] =
         get_settings(cls,
          current_user.id,
          current_user.customer_id,
          @@plugin_id)
    end

    # Get the dates for the week we're viewing
    session[:startdate] = session[:settings].weekstart || Date.today.beginning_of_week
    session[:enddate] = session[:startdate] + 6.days

    # Create view model vars
    @team_filter            = session[:team_filter] || ""
    @cust_filter            = session[:cust_filter] || ""
    @startdate              = session[:settings].weekstart || Date.today.beginning_of_week
    @enddate                = @startdate + 6.days
    @export_all             = session[:export_all]
    @overwrite_scheds       = session[:overwrite_scheds]
    @apply_to_all_customers = session[:apply_to_all_customers]
    @apply_to_future        = session[:apply_to_future]

    log 'team_filter', @team_filter
    log 'cust_filter', @cust_filter

    if session[:future_date].class == Date
      @future_date = session[:future_date].strftime "%m/%d/%Y"
    else
      @future_date = @enddate.strftime "%m/%d/%Y"
    end

    # Get workgroups
    @customers  = PsvmWorkgroup.where('wg_level = 3').order('wg_name')
    @activities = PsvmWorkgroup.where('wg_level = 5').order('wg_num')
    @teams      = PsvmWorkgroup.where('wg_level = 8').order('wg_name')

    # Get all the scheds for these filters
    scheds = get_filtered_scheds(@startdate, @enddate, 
                                 @team_filter, @cust_filter)
    # Get all their emps
    emps = PsvmEmp.where(filekey: scheds.map { |s| s.filekey })

    # Get all the emps assigned to patterns for these filters
    emps2 = get_filtered_emps(@team_filter, @cust_filter)

    # Add all the scheds for those emps
    scheds2 = PsvmSched.where(filekey: emps2.map { |e| e.filekey },
                               sch_date: @startdate..@enddate)
    # Merge both
    emps   += emps2
    scheds += scheds2

    # Remove duplicates and sort
    emps   = emps.uniq.sort_by &:fullname
    scheds = scheds.uniq.sort_by &:filekey

    # Make a viewweek
    @vw = PluginServiceMaster::ViewModels::ViewWeekVM.new(
      @startdate, 
      @enddate)

    # For each employee
    emps.each do |emp|

      # Make an empweek
      ew = PluginServiceMaster::ViewModels::EmpWeekVM.new(emp)

      # Add it to the viewweek
      @vw.emp_weeks << ew

      # For each pattern this emp is assigned to
      emp.patterns.each do |p|

        # Find the custweek for this pattern
        cw = nil
        customer = PsvmWorkgroup.where(wg_level: 3, wg_num: p.wg3).first
        ew.cust_weeks.each do |custweek|

          # See if we already have this custweek
          if custweek.customer.wg_num == p.wg3
            cw = custweek
            break
          end
        end

        # If we don't add it to the empweek
        if cw.nil?
          cw = PluginServiceMaster::ViewModels::CustWeekVM.new(
            customer)
          ew.cust_weeks << cw
        end

        # Find the teamweek for this sched
        tw = nil
        team = PsvmWorkgroup.where(wg_level: 8, wg_num: p.wg8).first
        cw.team_weeks.each do |teamweek|

          # See if we already have this teamweek
          if teamweek.team.wg_num == p.wg8
            tw = teamweek
            break
          end
        end

        # If we don't add it to the custweek
        if tw.nil?
          tw = PluginServiceMaster::ViewModels::TeamWeekVM.new(
            emp, customer, team, @startdate)
          cw.team_weeks << tw
        end
      end

      # For each sched
      scheds.each do |s|

        # If this sched is for this employee
        if s.filekey == emp.filekey

          # Find the custweek for this sched
          cw = nil
          customer = PsvmWorkgroup.where(
            wg_level: 3, wg_num: s.sch_wg3).first

          ew.cust_weeks.each do |custweek|

            # See if we already have this custweek
            if custweek.customer.wg_num == s.sch_wg3
              cw = custweek
              break
            end
          end

          # If we don't add it to the empweek
          if cw.nil?
            cw = PluginServiceMaster::ViewModels::CustWeekVM.new(
              customer)
            ew.cust_weeks << cw
          end

          # Find the teamweek for this sched
          tw = nil
          team = PsvmWorkgroup.where(
            wg_level: 8, wg_num: s.sch_wg8).first
          cw.team_weeks.each do |teamweek|

            # See if we already have this teamweek
            if teamweek.team.wg_num == s.sch_wg8
              tw = teamweek
              break
            end
          end

          # If we don't add it to the custweek
          if tw.nil?
            tw = PluginServiceMaster::ViewModels::TeamWeekVM.new(
              emp, customer, team, @startdate)
            cw.team_weeks << tw
          end

          # Add this schedule to the teamweek
          tw.day1 = s if s.sch_date.monday?
          tw.day2 = s if s.sch_date.tuesday?
          tw.day3 = s if s.sch_date.wednesday?
          tw.day4 = s if s.sch_date.thursday?
          tw.day5 = s if s.sch_date.friday?
          tw.day6 = s if s.sch_date.saturday?

          # Tally hours
          tw.total_hours += s.sch_hours_hund
          cw.total_hours += s.sch_hours_hund
          ew.total_hours += s.sch_hours_hund
        end
      end

      # # Look up any events for this employee
      # events = PsvmSched.where(is_event: true,
      #                          sch_wg3: customer.wg_num,
      #                          sch_date: @startdate..@enddate)

      # log 'events', events
      
      # # For each event
      # events.each do |e|

      #   # Create a teamweek for it
      #   tw = PluginServiceMaster::ViewModels::TeamWeekVM.new(
      #     emp, customer, 
      #     PsvmWorkgroup.new({ wg_level: 8, wg_name: e.label }),
      #     @startdate)
      #   cw.team_weeks << tw

      #   # Add this event to the teamweek
      #   tw.day1 = e if e.sch_date.monday?
      #   tw.day2 = e if e.sch_date.tuesday?
      #   tw.day3 = e if e.sch_date.wednesday?
      #   tw.day4 = e if e.sch_date.thursday?
      #   tw.day5 = e if e.sch_date.friday?
      #   tw.day6 = e if e.sch_date.saturday?

      #   # Tally hours
      #   tw.total_hours += e.sch_hours_hund
      #   cw.total_hours += e.sch_hours_hund
      #   ew.total_hours += e.sch_hours_hund
      # end

      # Check for any overlapping schedules
      ew.cust_weeks.each do |cw1|
        cw1.team_weeks.each do |tw1|
          ew.cust_weeks.each do |cw2|
            cw2.team_weeks.each do |tw2|
              if tw1.day1.id != tw2.day1.id &&
                 tw1.day1.sch_start_time < tw2.day1.sch_end_time &&
                 tw2.day1.sch_start_time < tw1.day1.sch_end_time
                 tw1.day1.overlapping = true;
                 tw2.day1.overlapping = true;
              end 
              if tw1.day2.id != tw2.day2.id &&
                 tw1.day2.sch_start_time < tw2.day2.sch_end_time &&
                 tw2.day2.sch_start_time < tw1.day2.sch_end_time
                 tw1.day2.overlapping = true;
                 tw2.day2.overlapping = true;
              end 
              if tw1.day3.id != tw2.day3.id &&
                 tw1.day3.sch_start_time < tw2.day3.sch_end_time &&
                 tw2.day3.sch_start_time < tw1.day3.sch_end_time
                 tw1.day3.overlapping = true;
                 tw2.day3.overlapping = true;
              end 
              if tw1.day4.id != tw2.day4.id &&
                 tw1.day4.sch_start_time < tw2.day4.sch_end_time &&
                 tw2.day4.sch_start_time < tw1.day4.sch_end_time
                 tw1.day4.overlapping = true;
                 tw2.day4.overlapping = true;
              end 
              if tw1.day5.id != tw2.day5.id &&
                 tw1.day5.sch_start_time < tw2.day5.sch_end_time &&
                 tw2.day5.sch_start_time < tw1.day5.sch_end_time
                 tw1.day5.overlapping = true;
                 tw2.day5.overlapping = true;
              end 
              if tw1.day6.id != tw2.day6.id &&
                 tw1.day6.sch_start_time < tw2.day6.sch_end_time &&
                 tw2.day6.sch_start_time < tw1.day6.sch_end_time
                 tw1.day6.overlapping = true;
                 tw2.day6.overlapping = true;
              end 
            end
          end
        end
      end

      # If total hours > 29, print exception
      ew.exceptions = 'Over limit!' if ew.total_hours >= 29.0
    end
  end

  def events
    log __method__

    # Get the dates for the week we're viewing
    session[:startdate] = session[:settings].weekstart || Date.today.beginning_of_week
    session[:enddate] = session[:startdate] + 6.days

    # Create view model vars
    @team_filter            = session[:team_filter] || ""
    @cust_filter            = session[:cust_filter] || ""
    @startdate              = session[:settings].weekstart || Date.today.beginning_of_week
    @enddate                = @startdate + 6.days

    log 'cust_filter', @cust_filter
    
    # Get workgroups
    @customers  = PsvmWorkgroup.where('wg_level = 3').order('wg_name')

    # Get all the events for these filters
    events = get_filtered_events(@startdate, @enddate, @cust_filter)

    # Get all their customers
    customers = PsvmWorkgroup.where(
      wg_level: 3, 
      wg_num: events.map { |e| e.sch_wg3 })
    .sort_by &:wg_name

    # If there were none, create a dummy customer
    if customers.nil? || customers.empty?
      customers = []
      customers << PsvmWorkgroup.new({ wg_level: 3, wg_name: 'None' })
    end

    # Make a viewweek
    @vw = PluginServiceMaster::ViewModels::ViewWeekVM.new(
      @startdate, 
      @enddate)

    # Make a dummy empweek
    emp = PsvmEmp.new
    ew = PluginServiceMaster::ViewModels::EmpWeekVM.new(emp)

    # Add it to the viewweek
    @vw.emp_weeks << ew

    # For each customer
    customers.each do |customer|

      # Make a custweek
      cw = PluginServiceMaster::ViewModels::CustWeekVM.new(
        customer)
      ew.cust_weeks << cw

      # Make a teamweek
      tw = PluginServiceMaster::ViewModels::TeamWeekVM.new(
        emp, customer, PsvmWorkgroup.new({ wg_level: 8, wg_name: 'None' }), @startdate)
      cw.team_weeks << tw

      # For each event
      events.each do |e|

        # If this event is for this customer
        if e.sch_wg3 == customer.wg_num

          # Add this event to the teamweek
          tw.day1 = e if e.sch_date.monday?
          tw.day2 = e if e.sch_date.tuesday?
          tw.day3 = e if e.sch_date.wednesday?
          tw.day4 = e if e.sch_date.thursday?
          tw.day5 = e if e.sch_date.friday?
          tw.day6 = e if e.sch_date.saturday?
        end
      end
    end
  end  

  def settings
    log __method__
  end

  def save_settings
    log __method__
  end

  def team_list
    log __method__
    @teams = PsvmWorkgroup.where('wg_level = 8').order('wg_num desc')
  end

  def customer_list
    log __method__
    @customers = PsvmWorkgroup.where(wg_level: 3).order('wg_name')
    @teams     = PsvmWorkgroup.where(wg_level: 8).order('wg_name')
    @activities = PsvmWorkgroup.where(wg_level: 5).select('wg_num, wg_name').order('wg_name')
  end

  def employee_list
    log __method__
    @employees = PsvmEmp.where(active_status: 0).order('last_name, first_name')
    @patterns  = PsvmPattern.order('wg3, wg8')
  end

  def event_list
    log __method__
  end

  def get_team
    log __method__
    team = PsvmWorkgroup.where(wg_level: 8, wg_num: params[:wg_num]).first
    render json: [ team ].to_json
  end

  def save_team
    log __method__
    team = PsvmWorkgroup.where(wg_level: 8, wg_num: params[:wg_num]).first
    team.wg_code = params[:wg_code]
    team.wg_name = params[:wg_name]
    team.save
    render json: true
  end

  def create_team
    log __method__
    max = PsvmWorkgroup.maximum("wg_num") + 1
    PsvmWorkgroup.create(wg_level: 8, wg_num: max, wg_name: 'New Team')
    render json: true
  end

  def delete_team
    log __method__
    team = PsvmWorkgroup.where(wg_level: 8, wg_num: params[:wg_num]).first
    team.destroy
    render json: true
  end

  def get_customer
    log __method__
    customer  = PsvmWorkgroup.where(wg_level: 3, wg_num: params[:wg_num]).first
    patterns  = PsvmPattern.where(wg3: params[:wg_num])
    teams     = PsvmWorkgroup.where(wg_level: 8, wg_num: patterns.map(&:wg8))
    render json: [ customer, teams ].to_json
  end

  def get_pattern
    log __method__
    customer  = PsvmWorkgroup.where(wg_level: 3, wg_num: params[:wg3]).first
    team      = PsvmWorkgroup.where(wg_level: 8, wg_num: params[:wg8]).first
    pattern   = PsvmPattern.where(wg3: params[:wg3], wg8: params[:wg8]).first
    employees = PsvmEmp.joins(:psvm_patterns)
                       .where(psvm_patterns: {  
                         wg3: params[:wg3], 
                         wg8: params[:wg8]   })
                       .uniq
    render json: [ customer, team, pattern, employees ].to_json
  end

  def save_pattern
    log __method__

    pattern = PsvmPattern.where(wg3: params[:wg3], wg8: params[:wg8]).first_or_initialize
    pattern.day1 = params[:day1]
    pattern.day2 = params[:day2]
    pattern.day3 = params[:day3]
    pattern.day4 = params[:day4]
    pattern.day5 = params[:day5]
    pattern.day6 = params[:day6]
    pattern.day7 = params[:day7]
    pattern.save
    render json: true
  end

  def create_pattern
    log __method__
    pattern = PsvmPattern.where(
      wg3: params[:wg3], 
      wg8: params[:wg8]).first_or_initialize
    pattern.save
    render json: true
  end

  def delete_pattern
    log __method__
    PsvmPattern.destroy(params[:id])
    render json: true
  end

  def get_employee
    log __method__
    employee = PsvmEmp.where(emp_id: params[:emp_id]).first
    patterns = employee.patterns.order(:wg3, :wg8)

    render json: [ 
      employee.as_json(methods: [:fullname]), 
      patterns.as_json(methods: [:customer_team_name]) 
    ]
  end

  def save_employee
    log __method__
    employee = PsvmEmp.where(emp_id: params[:emp_id]).first
    employee.first_name = params[:first_name]
    employee.last_name = params[:last_name]
    employee.save
    render json: true
  end

  def assign_pattern
    log __method__
    employee = PsvmEmp.where(emp_id: params[:emp_id]).first
    pattern = PsvmPattern.find(params[:pattern_id])
    employee.patterns << pattern
    employee.save
    render json: true
  end

  def delete_emp_pattern
    log __method__
    employee = PsvmEmp.where(emp_id: params[:emp_id]).first
    pattern = PsvmPattern.find(params[:pattern_id])
    employee.patterns.delete(pattern)
    employee.save
    render json: true
  end

  def import_employees
    log __method__
    cache_save current_user.id, 'svm_import_status', 'Initializing'
    cache_save current_user.id, 'svm_import_progress', '10'

    # Request employees from AoD, in the background
    Delayed::Job.enqueue PluginServiceMaster::ImportEmployees.new(
      current_user.id,
      session[:settings])

    render json: true
  end

  def import_workgroups
    log __method__
    cache_save current_user.id, 'svm_import_status', 'Initializing'
    cache_save current_user.id, 'svm_import_progress', '10'

    # Request wg3 (Customers) from AoD, in the background
    Delayed::Job.enqueue PluginServiceMaster::ImportWorkgroups.new(
      current_user.id,
      session[:settings],
      3)

    # Request wg5 (Activities) from AoD, in the background
    Delayed::Job.enqueue PluginServiceMaster::ImportWorkgroups.new(
      current_user.id,
      session[:settings],
      5)

    render json: true
  end

  def save_schedule
    log __method__
    schid = params[:schid]
    filekey = params[:filekey]
    sch_date = params[:sch_date]
    sch_start_time = params[:sch_start_time]
    sch_end_time = params[:sch_end_time]
    sch_wg3 = params[:sch_wg3]
    sch_wg8 = params[:sch_wg8]
    sch_wg5 = params[:sch_wg5]
    is_event = params[:is_event]
    label = params[:label]

    s = PsvmSched.where(id: schid).first_or_initialize
    s.filekey = filekey if filekey.present?
    s.sch_date = Date.parse(sch_date) if sch_date.present?
    s.sch_wg3 = sch_wg3 if sch_wg3.present?
    s.sch_wg8 = sch_wg8 if sch_wg8.present?
    s.sch_wg5 = sch_wg5 if sch_wg5.present?
    s.is_event = is_event if is_event.present?
    s.label = label if label.present?

    if sch_start_time.present?
      a = DateTime.parse(sch_start_time).utc 
      s.sch_start_time = DateTime.new(
        s.sch_date.year,
        s.sch_date.month,
        s.sch_date.day,
        a.hour,
        a.minute,
        a.second)
      .utc
    end

    if sch_end_time.present?
      a = DateTime.parse(sch_end_time).utc 
      s.sch_end_time = DateTime.new(
        s.sch_date.year,
        s.sch_date.month,
        s.sch_date.day,
        a.hour,
        a.minute,
        a.second)
      .utc
    end

    if s.sch_end_time < s.sch_start_time
      s.sch_end_time = s.sch_end_time + 1.days
    end

    s.sch_hours_hund = (s.sch_end_time - s.sch_start_time) / 3600
    s.save

    render json: true
  end

  def delete_schedule
    log __method__
    PsvmSched.destroy(params[:schid].to_i) if params[:schid].present?

    render json: true
  end

  def team_filter
    log __method__
    # Save the filter to the session
    session[:team_filter] = params[:team_filter]
    render json: true
  end

  def cust_filter
    log __method__
    # Save the filter to the session
    session[:cust_filter] = params[:cust_filter]
    render json: true
  end

  def next_week
    log __method__
    session[:settings].weekstart = session[:settings].weekstart + 7.days
    redirect_to action: 'schedules'
  end

  def prev_week
    log __method__
    session[:settings].weekstart = session[:settings].weekstart - 7.days
    redirect_to action: 'schedules'
  end

  def next_event_week
    log __method__
    session[:settings].weekstart = session[:settings].weekstart + 7.days
    redirect_to action: 'events'
  end

  def prev_event_week
    log __method__
    session[:settings].weekstart = session[:settings].weekstart - 7.days
    redirect_to action: 'events'
  end

  def export_scheds
    log __method__

    # Get the options
    session[:export_all] = params[:export_all].to_bool

    # Get the current week's dates
    start_date = session[:settings].weekstart
    end_date = start_date + 6.days
    
    scheds = []
    employees = []

    # If we're exporting all schedules
    if session[:export_all] == true

      # Set the end date far in the future, to get all scheds
      end_date = start_date + 1000.years

      scheds = PsvmSched.where(
        sch_date: start_date..end_date)
        .order('filekey, sch_date, sch_start_time').to_a
    else

      # Get the schedules currently being viewed
      employees = get_filtered_emps(session[:team_filter], session[:cust_filter])
      
      v = PluginServiceMaster::ViewModels::ViewWeekVM.new(
        start_date, 
        end_date, 
        get_emp_weeks(employees, start_date, end_date))

      # For each empweek
      v.emp_weeks.each do |ew|

        # For each custweek
        ew.cust_weeks.each do |cw|

          # Get the scheds
          scheds << cw.day1 if cw.day1.id.present?
          scheds << cw.day2 if cw.day2.id.present?
          scheds << cw.day3 if cw.day3.id.present?
          scheds << cw.day4 if cw.day4.id.present?
          scheds << cw.day5 if cw.day5.id.present?
          scheds << cw.day6 if cw.day6.id.present?
        end
      end
    end

    # Export them to AoD
    if scheds.length > 0
      cache_save current_user.id, 'svm_export_scheds_status', 'Initializing'
      cache_save current_user.id, 'svm_export_scheds_progress', '10'

      Delayed::Job.enqueue PluginServiceMaster::ExportToAod.new(
        current_user.id,
        session[:settings],
        start_date,
        end_date,
        scheds)
    end

    render json: true
  end

  def generate_scheds
    log __method__

    # Get the dates for the week we're viewing
    start_date = session[:settings].weekstart
    end_date = start_date + 6.days

    # Get the options
    session[:overwrite_scheds]       = params[:overwrite_scheds].to_bool
    session[:apply_to_all_customers] = params[:apply_to_all_customers].to_bool
    session[:apply_to_future]        = params[:apply_to_future].to_bool
    session[:future_date]            =
      Date.strptime(params[:future_date], "%m/%d/%Y") rescue end_date

    # Get the employees we're generating scheds for
    if session[:apply_to_all_customers] == true
      employees = PsvmEmp.where(active_status: 0)
    else

      # issues generating schedules?

      employees = get_filtered_emps(session[:team_filter],
                                    session[:cust_filter])
    end

    if session[:apply_to_future] == true &&
       session[:future_date] > end_date
      future_date = session[:future_date]
    else
      future_date = end_date
    end

    while start_date <= future_date
      # Get the current view
      vw = PluginServiceMaster::ViewModels::ViewWeekVM.new(
        start_date, 
        end_date, 
        get_emp_weeks(employees, start_date, end_date))

      # For each empweek
      vw.emp_weeks.each do |ew|

        # For each custweek
        ew.cust_weeks.each do |cw|

          # For each teamweek
          cw.team_weeks.each do |tw|

            filekey = tw.employee.filekey
            cust    = tw.customer.wg_num
            team    = tw.team.wg_num

            # If the customer has a pattern
            pattern = PsvmPattern.where(wg3: cust, wg8: team).first
            if pattern.present?

              # For each day that is unscheduled, get it from the pattern
              if (session[:overwrite_scheds] == true || cw.day1.id.nil?) &&
                  start_date + 0.days <= future_date && pattern.day1.present?
                    cw.day1 = convert_to_sched(filekey, cust, start_date + 0.days, pattern.day1, session[:overwrite_scheds])
              end
              if (session[:overwrite_scheds] == true || cw.day2.id.nil?) &&
                  start_date + 1.days <= future_date && pattern.day2.present?
                    cw.day2 = convert_to_sched(filekey, cust, start_date + 1.days, pattern.day2, session[:overwrite_scheds])
              end
              if (session[:overwrite_scheds] == true || cw.day3.id.nil?) &&
                  start_date + 2.days <= future_date && pattern.day3.present?
                    cw.day3 = convert_to_sched(filekey, cust, start_date + 2.days, pattern.day3, session[:overwrite_scheds])
              end
              if (session[:overwrite_scheds] == true || cw.day4.id.nil?) &&
                  start_date + 3.days <= future_date && pattern.day4.present?
                    cw.day4 = convert_to_sched(filekey, cust, start_date + 3.days, pattern.day4, session[:overwrite_scheds])
              end
              if (session[:overwrite_scheds] == true || cw.day5.id.nil?) &&
                  start_date + 4.days <= future_date && pattern.day5.present?
                    cw.day5 = convert_to_sched(filekey, cust, start_date + 4.days, pattern.day5, session[:overwrite_scheds])
              end
              if (session[:overwrite_scheds] == true || cw.day6.id.nil?) &&
                  start_date + 5.days <= future_date && pattern.day6.present?
                    cw.day6 = convert_to_sched(filekey, cust, start_date + 5.days, pattern.day6, session[:overwrite_scheds])
              end
            end
          end
        end
      end

      start_date += 7.days
      end_date += 7.days
    end

    redirect_to action: 'schedules'
  end

  def progress

    log __method__
    progress = cache_get current_user.id, 'svm_' + params[:progress_type] + '_progress'
    status   = cache_get current_user.id, 'svm_' + params[:progress_type] + '_status'

    if progress != '100'
      render json: { progress: progress, status: status }.to_json
    else
      render json: true
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
    sched.sch_wg6 = emp.wg6 if sched.sch_wg6.nil? || sched.sch_wg6 == 0
    sched.sch_wg7 = emp.wg7 if sched.sch_wg7.nil? || sched.sch_wg7 == 0
    sched.sch_wg8 = emp.wg8 if sched.sch_wg8.nil? || sched.sch_wg8 == 0
    sched.sch_wg9 = emp.wg9 if sched.sch_wg9.nil? || sched.sch_wg9 == 0
    sched.sch_wg1 = 1 if sched.sch_wg1 == 0
    sched.sch_wg2 = 1 if sched.sch_wg2 == 0
    sched.sch_wg3 = 1 if sched.sch_wg3 == 0
    sched.sch_wg4 = 1 if sched.sch_wg4 == 0
    sched.sch_wg5 = 1 if sched.sch_wg5 == 0
    sched.sch_wg6 = 1 if sched.sch_wg6 == 0
    sched.sch_wg7 = 1 if sched.sch_wg7 == 0
    sched.sch_wg8 = 1 if sched.sch_wg8 == 0
    sched.sch_wg9 = 1 if sched.sch_wg9 == 0
  end

  def get_filtered_scheds(startdate, enddate, team_filter, cust_filter)
    log __method__
    scheds = []

    # If we're filtering by customer only, 
    # get all scheds in date range, for this customer
    if team_filter.blank? && cust_filter.present?
      scheds = PsvmSched
        .where("is_event != true",
               sch_date: startdate..enddate, 
               sch_wg3: cust_filter)
        .order('filekey, sch_wg3, sch_wg8')

    # If we're filtering by team only, 
    # get all scheds in date range, for this team
    elsif team_filter.present? && cust_filter.blank?
      scheds = PsvmSched
        .where("is_event != true",
               sch_date: startdate..enddate, 
               sch_wg8: team_filter)
        .order('filekey, sch_wg3, sch_wg8')

    # If we're filtering by both, 
    # get all scheds in date range, for this customer/team
    elsif team_filter.present? && cust_filter.present?
      scheds = PsvmSched
        .where("is_event != true",
               sch_date: startdate..enddate, 
               sch_wg3: cust_filter,
               sch_wg8: team_filter)
        .order('filekey, sch_wg3, sch_wg8')
    end

    scheds
  end

  def get_filtered_events(startdate, enddate, cust_filter)
    log __method__
    events = []

    # If we're filtering by customer
    # get all events in date range, for this customer
    if cust_filter.present?
      events = PsvmSched
        .where("is_event = true AND label != ''")
        .where(sch_date: startdate..enddate, 
               sch_wg3: cust_filter)
        .order('sch_wg3')
    else
      # Else get all events in date range
      events = PsvmSched
        .where("is_event = true AND label != ''")
        .where(sch_date: startdate..enddate)
        .order('sch_wg3')
    end

    events
  end

  def get_filtered_emps(team_filter, cust_filter)
    log __method__
    employees = []

    # If we're filtering by customer only, 
    # get all employees assigned to this customer
    if team_filter.blank? && cust_filter.present?
      employees = PsvmEmp
        .joins(:psvm_patterns)
        .where(psvm_patterns: { wg3: cust_filter })
        .order('last_name')

    # If we're filtering by team only, 
    # get all employees assigned to this team
    elsif team_filter.present? && cust_filter.blank?
      employees = PsvmEmp
        .joins(:psvm_patterns)
        .where(psvm_patterns: { wg8: team_filter })
        .order('last_name')

    # If we're filtering by both, 
    # get all employees assigned to this customer/team
    elsif team_filter.present? && cust_filter.present?
      employees = PsvmEmp
        .joins(:psvm_patterns)
        .where(psvm_patterns: { wg3: cust_filter, wg8: team_filter })
        .order('last_name')
    end

    employees
  end

  def get_emp_weeks employees, start_date, end_date
    log __method__
    emp_weeks = []

    # For each employee
    employees.each do |emp|
      # Make an empweek
      ew = PluginServiceMaster::ViewModels::EmpWeekVM.new
      ew.employee = emp
      ew.cust_weeks = get_cust_weeks(emp, start_date, end_date)

      # Check for any overlapping schedules
      ew.cust_weeks.each do |cw1|
        ew.cust_weeks.each do |cw2|
          if cw1.day1.id != cw2.day1.id &&
             cw1.day1.sch_start_time < cw2.day1.sch_end_time &&
             cw2.day1.sch_start_time < cw1.day1.sch_end_time
             cw1.day1.overlapping = true;
             cw2.day1.overlapping = true;
          end
          if cw1.day2.id != cw2.day2.id &&
             cw1.day2.sch_start_time < cw2.day2.sch_end_time &&
             cw2.day2.sch_start_time < cw1.day2.sch_end_time
             cw1.day2.overlapping = true;
             cw2.day2.overlapping = true;
          end
          if cw1.day3.id != cw2.day3.id &&
             cw1.day3.sch_start_time < cw2.day3.sch_end_time &&
             cw2.day3.sch_start_time < cw1.day3.sch_end_time
             cw1.day3.overlapping = true;
             cw2.day3.overlapping = true;
          end
          if cw1.day4.id != cw2.day4.id &&
             cw1.day4.sch_start_time < cw2.day4.sch_end_time &&
             cw2.day4.sch_start_time < cw1.day4.sch_end_time
             cw1.day4.overlapping = true;
             cw2.day4.overlapping = true;
          end
          if cw1.day5.id != cw2.day5.id &&
             cw1.day5.sch_start_time < cw2.day5.sch_end_time &&
             cw2.day5.sch_start_time < cw1.day5.sch_end_time
             cw1.day5.overlapping = true;
             cw2.day5.overlapping = true;
          end
          if cw1.day6.id != cw2.day6.id &&
             cw1.day6.sch_start_time < cw2.day6.sch_end_time &&
             cw2.day6.sch_start_time < cw1.day6.sch_end_time
             cw1.day6.overlapping = true;
             cw2.day6.overlapping = true;
          end
        end
      end

      # Calculate total hours
      ew.total_hours = 0.0
      ew.cust_weeks.each do |cw|
        ew.total_hours += cw.total_hours
      end

      # If total hours > 29, print exception
      ew.exceptions = 'Over limit!' if ew.total_hours >= 29.0

      # Save empweek
      emp_weeks << ew
    end

    emp_weeks
  end

  def get_cust_weeks employee, start_date, end_date
    log __method__
    cust_weeks = []

    # Get the customer/teams this employee is assigned to
    assigned_custs = employee.patterns.map {|p| [ p.wg3, p.wg8 ]}

    # Get the customer/teams this employee is scheduled for
    scheduled_custs = PsvmSched.where(sch_date: start_date..end_date, filekey: employee.filekey)
      .select(:sch_wg3)
      .group(:sch_wg3)
      .map {|s| [ s.sch_wg3, s.sch_wg8 ]}

    # Merge both together
    all_custs = assigned_custs + scheduled_custs

    # Eliminate duplicates
    all_custs = all_custs.uniq

    # For each customer/team
    all_custs.each do |custnum|

      # Make a custweek
      cw = PluginServiceMaster::ViewModels::CustWeekVM.new
      cw.customer = PsvmWorkgroup.where(wg_level: 3, wg_num: custnum).first
      cw.total_hours = 0

      # Get schedules for this employee/customer
      scheds = PsvmSched.where(
        sch_date: start_date..end_date,
        filekey: employee.filekey,
        sch_wg3: custnum)
        .order('sch_date, sch_start_time')

      # For each sched
      scheds.each do |sched|
        # Plug it into a day on the custweek
        cw.day1 = sched if sched.sch_date.monday?
        cw.day2 = sched if sched.sch_date.tuesday?
        cw.day3 = sched if sched.sch_date.wednesday?
        cw.day4 = sched if sched.sch_date.thursday?
        cw.day5 = sched if sched.sch_date.friday?
        cw.day6 = sched if sched.sch_date.saturday?

        # Tally hours
        cw.total_hours += sched.sch_hours_hund
      end

      # Create default scheds on days that didn't have them
      if cw.day1.nil?
        cw.day1 = PsvmSched.new({
          filekey:  employee.filekey,
          sch_wg3:  custnum,
          sch_date: start_date + 0.days,
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc,
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      end
      if cw.day2.nil?
        cw.day2 = PsvmSched.new({
          filekey:  employee.filekey,
          sch_wg3:  custnum,
          sch_date: start_date + 1.days,
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc,
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      end
      if cw.day3.nil?
        cw.day3 = PsvmSched.new({
          filekey:  employee.filekey,
          sch_wg3:  custnum,
          sch_date: start_date + 2.days,
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc,
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      end
      if cw.day4.nil?
        cw.day4 = PsvmSched.new({
          filekey:  employee.filekey,
          sch_wg3:  custnum,
          sch_date: start_date + 3.days,
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc,
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      end
      if cw.day5.nil?
        cw.day5 = PsvmSched.new({
          filekey:  employee.filekey,
          sch_wg3:  custnum,
          sch_date: start_date + 4.days,
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc,
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      end
      if cw.day6.nil?
        cw.day6 = PsvmSched.new({
          filekey:  employee.filekey,
          sch_wg3:  custnum,
          sch_date: start_date + 5.days,
          sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc,
          sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      end

      cust_weeks << cw
    end

    cust_weeks
  end

  def convert_to_sched(filekey, cust, team, date, serialized, overwrite)
    log __method__

    s = JSON[serialized]

    s_start = Time.parse(s["start_time"])
    s_end = Time.parse(s["end_time"])
    sch_hours_hund = s["hours"].to_f
    sch_wg5 = s["activity"].to_i

    # If we're overwriting schedules
    if overwrite == true
      # Get any schedules on this day
      old_scheds = PsvmSched.where(filekey: filekey, sch_date: date)
      old_scheds.each do |o|
        o.destroy
      end
    end

    sched = PsvmSched.new
    sched.sch_date = date
    sched.filekey = filekey
    sched.sch_wg3 = cust
    sched.sch_wg8 = team
    sched.sch_start_time = DateTime.new(
      date.year, date.month, date.day, s_start.hour, s_start.min)
    sched.sch_end_time = DateTime.new(
      date.year, date.month, date.day, s_end.hour, s_end.min)

    sched.sch_hours_hund = sch_hours_hund
    sched.sch_wg5 = sch_wg5
    sched.save

    sched
  end

  def catch_exceptions
    yield
  rescue Exception => exc
    # Log the exception
    log 'exception', exc.message

    # Prepare backtrace
    bc = ActiveSupport::BacktraceCleaner.new
    # Ignore gems
    bc.add_silencer { |line| line =~ /gems/ }
    # Ignore ruby
    bc.add_silencer { |line| line =~ /ruby/ } 
    # Remove rails root from path names to make them shorter
    bc.add_filter   { |line| line.gsub("#{Rails.root}/", '') } 

    # Log backtrace
    log 'exception backtrace', bc.clean(exc.backtrace)

    # Alert the user
    flash.now[:alert] = exc.message
  end

end
