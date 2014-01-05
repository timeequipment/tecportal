class ApplicationController < ActionController::Base
  protect_from_forgery
  $debug_msg = ''
  $debug_hash = {}
end
