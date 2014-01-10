class CreateUserSettings < ActiveRecord::Migration
  def change
    create_table :user_settings do |t|
      t.integer :user_id
      t.integer :plugin_id
      t.text :data

      t.timestamps
    end

    add_index(:user_settings, [:user_id, :plugin_id])
  end
end
