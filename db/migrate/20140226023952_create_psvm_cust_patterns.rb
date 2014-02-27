class CreatePsvmCustPatterns < ActiveRecord::Migration
  def change
    create_table :psvm_cust_patterns do |t|
      t.integer  :wg_level
      t.integer  :wg_num
      t.string   :day1
      t.string   :day2
      t.string   :day3
      t.string   :day4
      t.string   :day5
      t.string   :day6
      t.string   :day7

      t.timestamps
    end

    add_index :psvm_cust_patterns, [:wg_level, :wg_num], name: 'psvm_cust_patterns_wg_level_wg_num'
  end
end
