class CreatePlugins < ActiveRecord::Migration
  def change
    create_table :plugins do |t|
      t.integer :type
      t.string :name
      t.string :description

      t.timestamps
    end

    add_index :plugins, :id, :unique => true
  end
end