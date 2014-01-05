class CreateCustomersPlugins < ActiveRecord::Migration
  def change
    create_table :customers_plugins do |t|
      t.integer :customer_id
      t.integer :plugin_id
    end

    # Adding the index can massively speed up join tables. Don't use the
    # unique if you allow duplicates.
#    add_index(:customers_plugins, [:customer_id, :plugin_id], :unique => true)
  end
end

