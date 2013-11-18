class DashboardController < ApplicationController
	before_filter :authenticate_user!

  def index
  	a = Time.now.hour
  	if a < 12 
  		@daypart = "morning"
  	elsif a < 18
  		@daypart = "afternoon"
  	else 
  		@daypart = "evening"
  	end
  end
end
