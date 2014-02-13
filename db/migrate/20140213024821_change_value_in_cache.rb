class ChangeValueInCache < ActiveRecord::Migration
  def up
    change_column :caches, :value, :text
  end

  def down
    change_column :caches, :value, :string
  end
end
