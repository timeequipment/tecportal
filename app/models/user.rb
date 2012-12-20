class User
  include Mongoid::Document

  # --------------------------------------------------------------------
  # Regarding 'Forgot your password'
  #
  #   If you want to utilize 'Forgot your password' links, 
  #   then add :recoverable to the list below, and uncomment the  
  #   Recoverable section, then run rake db:migrate.
  #   Also, you'll have to ensure that ActionMailer is setup and working, 
  #   which I've set it up in the app to use gmail.com.  You'll have to 
  #   identify an email service and an email address which will send the 
  #   'Forgot your password' emails to the users.  
  #
  #   See:  config/environment/development.rb for email setup
  #
  #---------------------------------------------------------------------

  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :rememberable, :trackable, :validatable, :authentication_keys => [:username] 

  ## Database authenticatable
  field :username,           :type => String, :default => ""
  field :email,              :type => String, :default => ""
  field :encrypted_password, :type => String, :default => ""

  validates_presence_of :username
  validates_presence_of :email
  validates_presence_of :encrypted_password
  
  ## Recoverable 
  # field :reset_password_token,   :type => String
  # field :reset_password_sent_at, :type => Time

  ## Rememberable
  field :remember_created_at, :type => Time

  ## Trackable
  field :sign_in_count,      :type => Integer, :default => 0
  field :current_sign_in_at, :type => Time
  field :last_sign_in_at,    :type => Time
  field :current_sign_in_ip, :type => String
  field :last_sign_in_ip,    :type => String

  ## Confirmable
  # field :confirmation_token,   :type => String
  # field :confirmed_at,         :type => Time
  # field :confirmation_sent_at, :type => Time
  # field :unconfirmed_email,    :type => String # Only if using reconfirmable

  ## Lockable
  # field :failed_attempts, :type => Integer, :default => 0 # Only if lock strategy is :failed_attempts
  # field :unlock_token,    :type => String # Only if unlock strategy is :email or :both
  # field :locked_at,       :type => Time

  ## Token authenticatable
  # field :authentication_token, :type => String

  def email_required?
    false
  end
end


