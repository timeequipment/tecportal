class CreatePsvmScheds < ActiveRecord::Migration
  def change
    create_table :psvm_scheds do |t|
      t.integer  :filekey
      t.date     :sch_date
      t.datetime :sch_start_time
      t.datetime :sch_end_time
      t.integer  :sch_hours
      t.float    :sch_rate
      t.float    :sch_hours_hund
      t.integer  :sch_type
      t.integer  :sch_style
      t.integer  :sch_patt_id
      t.integer  :benefit_id
      t.integer  :pay_des_id
      t.integer  :sch_wg1
      t.integer  :sch_wg2
      t.integer  :sch_wg3
      t.integer  :sch_wg4
      t.integer  :sch_wg5
      t.integer  :sch_wg6
      t.integer  :sch_wg7
      t.integer  :unique_id

      t.timestamps
    end

    add_index :psvm_scheds, [:filekey, :sch_date, :sch_start_time], name: 'psvm_scheds_filekey_sch_date_sch_start_time'
  end
end
