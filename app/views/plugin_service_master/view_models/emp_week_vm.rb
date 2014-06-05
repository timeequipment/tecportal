module PluginServiceMaster::ViewModels

  class EmpWeekVM
    
    attr_accessor \
      :employee,
      :cust_weeks,
      :total_hours,
      :exceptions

    def initialize(employee)
      @employee = employee
      @cust_weeks = []
      @total_hours = 0.0
      @exceptions = ''
    end

  end
end
