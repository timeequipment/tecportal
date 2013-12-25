class Plugin < ActiveRecord::Base
  has_and_belongs_to_many :customers
  
  attr_accessible :description, :name, :type
end
