# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)
run Tecportal::Application

# force Rails into production mode when                          
# you don't control web/app server and can't set it the proper way                  
ENV['RAILS_ENV'] ||= 'production'