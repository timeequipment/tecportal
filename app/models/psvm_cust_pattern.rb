class PsvmCustPattern < ActiveRecord::Base
  belongs_to :psvm_workgroup

  attr_accessible :wg_level, :wg_num, :day1, :day2, :day3, :day4, :day5, :day6, :day7
end
