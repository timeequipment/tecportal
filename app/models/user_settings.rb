class UserSettings < ActiveRecord::Base
  belongs_to :user
  belongs_to :plugin

  attr_accessible :data
end
