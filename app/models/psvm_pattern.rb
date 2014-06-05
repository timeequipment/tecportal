class PsvmPattern < ActiveRecord::Base
  has_and_belongs_to_many :psvm_emps

  attr_accessible \
    :wg1, :wg2, :wg3, :wg4, :wg5, :wg6, :wg7, :wg8, :wg9, 
    :day1, :day2, :day3, :day4, :day5, :day6, :day7,
    :day8, :day9, :day10, :day11, :day12, :day13, :day14

  def customer_team_name
    customer = PsvmWorkgroup.where(wg_level: 3, wg_num: wg3).first
    customer_name = customer.wg_name if customer.present?

    team = PsvmWorkgroup.where(wg_level: 8, wg_num: wg8).first
    team_name = team.wg_name if team.present?

    "#{ customer_name } - #{ team_name }"
  end
end
