class PsvmEmpWorkgroup < ActiveRecord::Base
  belongs_to :psvm_emp
  belongs_to :psvm_workgroup

  attr_accessible \
    :psvm_emp_id,
    :psvm_workgroup_id
end
