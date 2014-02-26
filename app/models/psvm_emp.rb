class PsvmEmp < ActiveRecord::Base
  has_many :psvm_scheds

  attr_accessible \
    :filekey, 
    :last_name, 
    :first_name, 
    :initial, 
    :emp_id, 
    :ssn, 
    :badge, 
    :active_status, 
    :hire_date, 
    :wg1, 
    :wg2, 
    :wg3, 
    :wg4, 
    :wg5, 
    :wg6, 
    :wg7, 
    :current_rate, 
    :pay_type_id, 
    :pay_class_id, 
    :sch_patt_id, 
    :hourly_status_id, 
    :clock_group_id, 
    :birth_date, 
    :custom1, 
    :custom2, 
    :custom3, 
    :custom4, 
    :custom5, 
    :custom6

  def fullname 
    "#{ last_name }, #{ first_name }"
  end
end
