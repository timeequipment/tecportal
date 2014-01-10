class CreateCustomerSettings < ActiveRecord::Migration
  def change
    create_table :customer_settings do |t|
      t.integer :customer_id
      t.integer :plugin_id
      t.text :data

      t.timestamps
    end

    add_index(:customer_settings, [:customer_id, :plugin_id])
  end
end
