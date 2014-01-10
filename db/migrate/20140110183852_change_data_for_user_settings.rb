class ChangeDataForUserSettings < ActiveRecord::Migration
  def up
    change_column :user_settings, :data, :text
  end

  def down
    change_column :user_settings, :data, :string
  end
end
