class CreatePsvmEmpsPsvmPatterns < ActiveRecord::Migration
  def change
    create_table :psvm_emps_psvm_patterns do |t|
      t.integer :psvm_emp_id
      t.integer :psvm_pattern_id
    end

   # Adding the index can massively speed up join tables. Don't use the
   # unique if you allow duplicates.
   add_index :psvm_emps_psvm_patterns, [:psvm_emp_id],     name: 'psvm_emps_psvm_patterns_psvm_emp_id'
   add_index :psvm_emps_psvm_patterns, [:psvm_pattern_id], name: 'psvm_emps_psvm_patterns_psvm_pattern_id'
  end
end
