module PluginServiceMaster::ViewModels

  class ViewWeekVM
    
    attr_accessor \
      :start_date,
      :end_date,
      :emp_weeks,
      :day1_exceptions,
      :day2_exceptions,
      :day3_exceptions,
      :day4_exceptions,
      :day5_exceptions,
      :day6_exceptions,
      :day7_exceptions

    def initialize(start_date, end_date)
      @start_date = start_date
      @end_date = end_date
      @emp_weeks = []
    end

  end
end
