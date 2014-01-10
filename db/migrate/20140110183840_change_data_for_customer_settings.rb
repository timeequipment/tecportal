class ChangeDataForCustomerSettings < ActiveRecord::Migration
  def change
    change_column :customer_settings, :data, :text
  end
end
