class AddUserIdToCaches < ActiveRecord::Migration
  def change
    add_column :caches, :user_id, :integer
  end
end
