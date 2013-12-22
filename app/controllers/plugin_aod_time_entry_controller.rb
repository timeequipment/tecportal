class PluginAodTimeEntryController < ApplicationController
  before_filter :authenticate_user!

  account = ""
  username = ""
  password = ""

  # Get User Settings

  # Get Customer Settings

  # Create interface to AoD
  @@aod = PluginsHelper::AodInterface.new(account, username, password)

  def index
  end

  def settings
  end

  def start  	
  	# @@aod = PluginsHelper::AodInterface.new(account, username, password)
  	# response = @@aod.extract_ranged_transactions_using_hyper_query( message: { 
  	# 	hyperQueryName: "All Employees", 
  	# 	dateRangeEnum: "drToday", 
  	# 	minDate: "", 
  	# 	maxDate: "" 
  	# })	
  	# @transactions = response.body[:t_ae_emp_transaction]
  end

  def end
  end
end
