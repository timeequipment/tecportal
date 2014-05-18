class CreatePsvmPatterns < ActiveRecord::Migration
  def change
    create_table :psvm_patterns do |t|
      t.integer  :wg1
      t.integer  :wg2
      t.integer  :wg3
      t.integer  :wg4
      t.integer  :wg5
      t.integer  :wg6
      t.integer  :wg7
      t.integer  :wg8
      t.integer  :wg9
      t.string   :day1
      t.string   :day2
      t.string   :day3
      t.string   :day4
      t.string   :day5
      t.string   :day6
      t.string   :day7
      t.string   :day8
      t.string   :day9
      t.string   :day10
      t.string   :day11
      t.string   :day12
      t.string   :day13
      t.string   :day14

      t.timestamps
    end

    add_index :psvm_patterns, [
      :wg1, 
      :wg2, 
      :wg3, 
      :wg4, 
      :wg5, 
      :wg6, 
      :wg7, 
      :wg8, 
      :wg9], name: 'psvm_patterns_wg1_wg2_wg3_wg4_wg5_wg6_wg7_wg8_wg9'
  end
end
