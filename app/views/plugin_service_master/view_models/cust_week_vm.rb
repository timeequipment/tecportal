module PluginServiceMaster::ViewModels

  class CustWeekVM
    
    attr_accessor \
      :customer,
      :team_weeks,
      :total_hours

    def initialize(customer)
      @customer = customer
      @team_weeks = []
      @total_hours = 0.0
    end

  end
end
