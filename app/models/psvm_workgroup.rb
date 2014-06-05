class PsvmWorkgroup < ActiveRecord::Base

  attr_accessible :wg_level, :wg_num, :wg_code, :wg_name

  def after_initialize(a = {}, options = {})
    self[:wg_level] = a[:wg_level] if a[:wg_level].present?
    self[:wg_num]   = a[:wg_num]   if a[:wg_num].present?
    self[:wg_code]  = a[:wg_code]  if a[:wg_code].present?
    self[:wg_name]  = a[:wg_name]  if a[:wg_name].present?
  end
end
