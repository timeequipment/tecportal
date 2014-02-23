class CreatePsvmWg3 < ActiveRecord::Migration
  def change
    create_table :psvm_wg3 do |t|
      t.integer  :wg_num
      t.string   :wg_code
      t.string   :wg_name

      t.timestamps
    end

    add_index :psvm_wg3, [:wg_num], name: 'psvm_wg3_wg_num'
  end
end
