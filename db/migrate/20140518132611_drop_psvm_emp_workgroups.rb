class DropPsvmEmpWorkgroups < ActiveRecord::Migration
  def up
    drop_table :psvm_emp_workgroups
  end

  def down
  end
end
