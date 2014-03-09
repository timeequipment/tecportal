class PsvmSched < ActiveRecord::Base
  belongs_to :psvm_emp

    attr_accessible \
      :filekey,
      :sch_date,
      :sch_start_time,
      :sch_end_time,
      :sch_hours,
      :sch_rate,
      :sch_hours_hund,
      :sch_type,
      :sch_style,
      :sch_patt_id,
      :benefit_id,
      :pay_des_id,
      :sch_wg1,
      :sch_wg2,
      :sch_wg3,
      :sch_wg4,
      :sch_wg5,
      :sch_wg6,
      :sch_wg7,
      :unique_id

    def initialize 
      @filekey = 0
      @sch_date = Date.new
      @sch_start_time = DateTime.new
      @sch_end_time = DateTime.new
      @sch_hours = 0
      @sch_rate = 0
      @sch_hours_hund = 0
      @sch_type = 0
      @sch_style = 0
      @sch_patt_id = 0
      @benefit_id = 0
      @pay_des_id = 0
      @sch_wg1 = 0
      @sch_wg2 = 0
      @sch_wg3 = 0
      @sch_wg4 = 0
      @sch_wg5 = 0
      @sch_wg6 = 0
      @sch_wg7 = 0
      @unique_id = 0
    end

    # def to_s
    #   @sch_start_time.strftime('%T') + ', ' + @sch_end_time.strftime('%T')
    # end
end
