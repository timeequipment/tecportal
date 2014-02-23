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
end
