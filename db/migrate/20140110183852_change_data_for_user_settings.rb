class ChangeDataForUserSettings < ActiveRecord::Migration
  def change
    change_column :user_settings, :data, :text
  end
end
