class AddTeamsAndEventsToPsvmScheds < ActiveRecord::Migration
  def change
    add_column :psvm_scheds, :sch_wg8, :integer
    add_column :psvm_scheds, :sch_wg9, :integer
    add_column :psvm_scheds, :is_event, :boolean
  end
end
