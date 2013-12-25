class Customer < ActiveRecord::Base
  has_many :users
  has_and_belongs_to_many :plugins
  has_many :settings, :class_name => "CustomerSettings"

  attr_accessible :address1, :address2, :city, :description, :fax, :mainphone, :name, :state, :status, :website, :zip
end
