class UserSettings < ActiveRecord::Base
  belongs_to :user
  belongs_to :plugin

  attr_accessible :user_id, :plugin_id, :data
end
