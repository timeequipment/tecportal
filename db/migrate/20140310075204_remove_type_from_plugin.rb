class RemoveTypeFromPlugin < ActiveRecord::Migration
  def up
    remove_column :plugins, :type
  end

  def down
    add_column :plugins, :type, :integer
  end
end
