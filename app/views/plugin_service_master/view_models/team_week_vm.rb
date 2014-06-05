module PluginServiceMaster::ViewModels

  class TeamWeekVM
    include ApplicationHelper
    
    attr_accessor \
      :employee,
      :customer,
      :team,
      :day1,
      :day2,
      :day3,
      :day4,
      :day5,
      :day6,
      :day7,
      :total_hours

    def initialize(employee, customer, team, startdate)
      @employee = employee
      @customer = customer
      @team = team

      @day1 = PsvmSched.new({
        filekey:  employee.filekey,
        sch_wg3:  customer.wg_num,
        sch_wg8:  team.wg_num,
        sch_date: startdate + 0.days,
        sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc,
        sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      @day2 = PsvmSched.new({
        filekey:  employee.filekey,
        sch_wg3:  customer.wg_num,
        sch_wg8:  team.wg_num,
        sch_date: startdate + 1.days,
        sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc,
        sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      @day3 = PsvmSched.new({
        filekey:  employee.filekey,
        sch_wg3:  customer.wg_num,
        sch_wg8:  team.wg_num,
        sch_date: startdate + 2.days,
        sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc,
        sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      @day4 = PsvmSched.new({
        filekey:  employee.filekey,
        sch_wg3:  customer.wg_num,
        sch_wg8:  team.wg_num,
        sch_date: startdate + 3.days,
        sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc,
        sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      @day5 = PsvmSched.new({
        filekey:  employee.filekey,
        sch_wg3:  customer.wg_num,
        sch_wg8:  team.wg_num,
        sch_date: startdate + 4.days,
        sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc,
        sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})
      @day6 = PsvmSched.new({
        filekey:  employee.filekey,
        sch_wg3:  customer.wg_num,
        sch_wg8:  team.wg_num,
        sch_date: startdate + 5.days,
        sch_start_time: DateTime.new(2000, 1, 1, 0, 0, 0).utc,
        sch_end_time:   DateTime.new(2000, 1, 1, 0, 0, 0).utc})

      @total_hours = 0.0
    end

  end
end
