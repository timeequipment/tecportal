class AddLabelToPsvmScheds < ActiveRecord::Migration
  def change
    add_column :psvm_scheds, :label, :string
  end
end
