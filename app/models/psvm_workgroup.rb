class PsvmWorkgroup < ActiveRecord::Base
  has_many :psvm_emp_workgroups
  has_many :psvm_emps, through: :psvm_emp_workgroups

  attr_accessible :wg_level, :wg_num, :wg_code, :wg_name

  def pattern
    PsvmCustPattern.where(wg_level: wg_level, wg_num: wg_num).first
  end

end
