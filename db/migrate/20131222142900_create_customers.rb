class CreateCustomers < ActiveRecord::Migration
  def change
    create_table :customers do |t|
      t.string :name
      t.string :description
      t.integer :status
      t.string :website
      t.string :mainphone
      t.string :fax
      t.string :address1
      t.string :address2
      t.string :city
      t.string :state
      t.string :zip

      t.timestamps
    end
    
    add_index :customers, :id, :unique => true
  end
end
