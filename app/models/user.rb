class User < ActiveRecord::Base
  belongs_to :customer
  has_many :settings, :class_name => "UserSettings"
  
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :rememberable,
         :timeoutable, :trackable, :validatable,
         :recoverable, :authentication_keys => [:name] 
         #,:confirmable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :role_ids, :as => :admin
  attr_accessible :email, :password, :password_confirmation, 
    :remember_me, :name, :sys_admin, :customer_admin, :customer_id

  def email_required?
    true
  end  
end
