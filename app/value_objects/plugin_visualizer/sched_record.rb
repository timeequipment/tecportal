module PluginVisualizer

  class SchedRecord
    attr_accessor \
      :lastname, 
      :firstname, 
      :employeeid, 
      :intime, 
      :outtime, 
      :hours, 
      :earningscode, 
      :lunchplan, 
      :prepaiddate, 
      :workedflag, 
      :scheduletype, 
      :timezone

    def to_s
      @lastname.to_s.gsub(",", "") + "," +
      @firstname.to_s.gsub(",", "") + "," +
      @employeeid.to_s.gsub(",", "") + "," +
      @intime.strftime("%-m/%-d/%Y %H:%M") + "," +
      @outtime.strftime("%-m/%-d/%Y %H:%M") + "," +
      @hours.to_f.round(2).to_s + "," +
      @earningscode.to_s.gsub(",", "") + "," +
      @lunchplan.to_s.gsub(",", "") + "," +
      @prepaiddate.to_s + "," +
      @workedflag.to_s + "," +
      @scheduletype.to_s + "," +
      @timezone.to_s.gsub(",", "")
    end
  end
end