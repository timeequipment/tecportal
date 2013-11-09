# Load the rails application
require File.expand_path('../application', __FILE__)

# Load the app's custom environment variables here, so that they are loaded before environments/*.rb
env_vars = File.join(Rails.root, 'config', 'env_vars.rb')
load(env_vars) if File.exists?(env_vars)
env_vars = File.join(Rails.root, 'config', 'env_vars_hidden.rb')
load(env_vars) if File.exists?(env_vars)

# Initialize the rails application
Tecportal::Application.initialize!
