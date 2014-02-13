class CreateCaches < ActiveRecord::Migration
  def change
    create_table :caches do |t|
      t.string :key
      t.string :value

      t.timestamps
    end
  end
end
