class CreatePsvmWorkgroups < ActiveRecord::Migration
  def change
    create_table :psvm_workgroups do |t|
      t.integer  :wg_level
      t.integer  :wg_num
      t.string   :wg_code
      t.string   :wg_name

      t.timestamps
    end

    add_index :psvm_workgroups, [:wg_num], name: 'psvm_workgroups_wg_num'
  end
end
