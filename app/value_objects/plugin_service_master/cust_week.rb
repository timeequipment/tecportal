module PluginServiceMaster

  class CustWeek
    
    attr_accessor \
      :customer,
      :day1,
      :day2,
      :day3,
      :day4,
      :day5,
      :day6,
      :day7,
      :total_hours

    def initialize
      @customer = nil
      @day1 = nil
      @day2 = nil
      @day3 = nil
      @day4 = nil
      @day5 = nil
      @day6 = nil
      @day7 = nil
      @total_hours = 0.0
    end

  end
end
