class PsvmPattern < ActiveRecord::Base
  has_and_belongs_to_many :psvm_emps

  attr_accessible \
    :wg1, :wg2, :wg3, :wg4, :wg5, :wg6, :wg7, :wg8, :wg9, 
    :day1, :day2, :day3, :day4, :day5, :day6, :day7,
    :day8, :day9, :day10, :day11, :day12, :day13, :day14
end
