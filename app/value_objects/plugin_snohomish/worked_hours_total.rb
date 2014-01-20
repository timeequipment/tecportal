module PluginSnohomish

  class WorkedHoursTotal
    include ActiveModel::Validations
    include ActiveModel::Conversion
    extend ActiveModel::Naming
    
    attr_accessor :empid, :dateworked, :lastpunch, :totalminutes

    def initializer 
      @empid = ''
      @dateworked = DateTime.new
      @lastpunch = DateTime.new
      @totalminutes = 0
    end

    def to_s
      @empid.to_s + ', ' + 
      @dateworked.to_datetime.strftime('%D') + ' '
      @lastpunch.to_datetime.strftime('%T') + ', Mins: ' +
      @totalminutes.to_s
    end
  end
end
