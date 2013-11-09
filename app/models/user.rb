class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :rememberable,
         :timeoutable, :trackable, :validatable,
         :recoverable, :authentication_keys => [:email] 
         #,:confirmable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :role_ids, :as => :admin
  attr_accessible :username, :name, :is_admin, :email, :password, :password_confirmation, :remember_me

  def email_required?
    true
  end  
end
