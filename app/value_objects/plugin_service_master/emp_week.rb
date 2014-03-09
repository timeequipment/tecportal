module PluginServiceMaster

  class EmpWeek
    
    attr_accessor \
      :employee,
      :cust_weeks,
      :total_hours,
      :exceptions

    def initialize 
      @employee = PsvmEmp.new
      @cust_weeks = []
      @total_hours = 0.0
      @exceptions = ''
    end

  end
end
