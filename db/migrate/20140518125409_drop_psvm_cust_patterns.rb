class DropPsvmCustPatterns < ActiveRecord::Migration
  def up
    drop_table :psvm_cust_patterns
  end

  def down
  end
end
