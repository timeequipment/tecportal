class CustomerSettings < ActiveRecord::Base
  belongs_to :customer
  belongs_to :plugin

  attr_accessible :customer_id, :plugin_id, :data
end
