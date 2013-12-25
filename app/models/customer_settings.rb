class CustomerSettings < ActiveRecord::Base
  belongs_to :customer
  belongs_to :plugin

  attr_accessible :data
end
