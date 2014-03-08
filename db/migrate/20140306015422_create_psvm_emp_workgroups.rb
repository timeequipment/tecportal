class CreatePsvmEmpWorkgroups < ActiveRecord::Migration
  def change
    create_table :psvm_emp_workgroups do |t|
      t.integer :psvm_emp_id
      t.integer :psvm_workgroup_id
    end

    # Adding the index can massively speed up join tables. Don't use the
    # unique if you allow duplicates.
   add_index :psvm_emp_workgroups, [:psvm_emp_id, :psvm_workgroup_id]
  end
end