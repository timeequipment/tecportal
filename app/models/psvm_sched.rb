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

    def after_initialize(attributes = {}, options = {})
      self[:filekey] = attributes[:filekey] if attributes[:filekey].present?
      self[:sch_wg3] = attributes[:sch_wg3] if attributes[:sch_wg3].present?
      self[:sch_date] = attributes[:sch_date] if attributes[:sch_date].present?
      self[:sch_start_time] = attributes[:sch_start_time] if attributes[:sch_start_time].present?
      self[:sch_end_time] = attributes[:sch_end_time] if attributes[:sch_end_time].present?
    end


    # def to_s
    #   @sch_start_time.strftime('%T') + ', ' + @sch_end_time.strftime('%T')
    # end
end
