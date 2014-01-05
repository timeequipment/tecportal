class HomeController < ApplicationController

  def index
  	if user_signed_in?
  		redirect_to :action => 'dashboard'
  	end
  end

  def dashboard
    if !user_signed_in?
      redirect_to :action => 'index'
    else
      # Get PST local time
      zone = ActiveSupport::TimeZone[-8]  
      psttime = DateTime.now.in_time_zone(zone)
      psthour = psttime.hour

      # Show 'morning', 'afternoon', or 'evening' based on PST
      if psthour < 12 
        @daypart = "morning"
      elsif psthour < 18
        @daypart = "afternoon"
      else 
        @daypart = "evening"
      end  
    end
  end
end
