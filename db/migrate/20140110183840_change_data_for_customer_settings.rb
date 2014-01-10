class ChangeDataForCustomerSettings < ActiveRecord::Migration
  def up
    change_column :customer_settings, :data, :text
  end

  def down
    change_column :customer_settings, :data, :string
  end
end
