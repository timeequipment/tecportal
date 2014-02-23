class CreatePsvmEmps < ActiveRecord::Migration
  def change
    create_table :psvm_emps do |t|
      t.integer  :filekey
      t.string   :last_name
      t.string   :first_name
      t.string   :initial
      t.string   :emp_id
      t.string   :ssn
      t.string   :badge
      t.integer  :active_status
      t.datetime :hire_date
      t.integer  :wg1
      t.integer  :wg2
      t.integer  :wg3
      t.integer  :wg4
      t.integer  :wg5
      t.integer  :wg6
      t.integer  :wg7
      t.float    :current_rate
      t.integer  :pay_type_id
      t.integer  :pay_class_id
      t.integer  :sch_patt_id
      t.integer  :hourly_status_id
      t.integer  :clock_group_id
      t.datetime :birth_date
      t.string   :custom1
      t.string   :custom2
      t.string   :custom3
      t.string   :custom4
      t.string   :custom5
      t.string   :custom6

      t.timestamps
    end

    add_index :psvm_emps, [:filekey], name: 'psvm_scheds_filekey'
  end
end
