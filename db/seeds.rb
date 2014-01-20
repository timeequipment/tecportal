# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

puts 'CREATING SYSADMIN USER'
user = User.create!(
  :id => 1,
  :name => 'admin', 
  :email => 'admin@admin.com', 
  :password => 'password', 
  :password_confirmation => 'password', 
  :sys_admin => true,
  :customer_id => nil )
puts 'New user created: ' << user.name

puts 'CREATING CUSTOMER: Protocall Services'
cust = Customer.create!(
  :id => 1,
  :name => 'Protocall Services' )
puts 'New customer created: ' << cust.name

puts 'CREATING CUSTOMER: FMC'
cust = Customer.create!(
  :id => 2,
  :name => 'FMC' )
puts 'New customer created: ' << cust.name

puts 'CREATING CUSTOMER: Snohomish'
cust = Customer.create!(
  :id => 3,
  :name => 'Snohomish' )
puts 'New customer created: ' << cust.name

puts 'CREATING PLUGIN: Visualizer'
plugin = Plugin.create!(
  :id => 1, 
  :name => 'Visualizer')
puts 'New plugin created: ' << plugin.name

puts 'CREATING PLUGIN: FMC Payroll Export'
plugin = Plugin.create!(
  :id => 2, 
  :name => 'FMC Payroll Export')
puts 'New plugin created: ' << plugin.name

puts 'CREATING PLUGIN: Snohomish Timecard Editor'
plugin = Plugin.create!(
  :id => 3, 
  :name => 'Snohomish Timecard Editor')
puts 'New plugin created: ' << plugin.name

puts 'CREATING CUSTOMER ADMIN FOR: Protocall Services'
user = User.create!(
  :name => 'psadmin', 
  :email => 'psadmin@admin.com', 
  :password => 'password', 
  :password_confirmation => 'password', 
  :sys_admin => false,
  :customer_admin => true,
  :customer_id => 1 )
puts 'New user created: ' << user.name

puts 'CREATING CUSTOMER ADMIN FOR: FMC'
user = User.create!(
  :name => 'fmcadmin', 
  :email => 'fmcadmin@admin.com', 
  :password => 'password', 
  :password_confirmation => 'password', 
  :sys_admin => false,
  :customer_admin => true,
  :customer_id => 2 )
puts 'New user created: ' << user.name

puts 'CREATING CUSTOMER ADMIN FOR: Snohomish'
user = User.create!(
  :name => 'snoadmin', 
  :email => 'snoadmin@admin.com', 
  :password => 'password', 
  :password_confirmation => 'password', 
  :sys_admin => false,
  :customer_admin => true,
  :customer_id => 3 )
puts 'New user created: ' << user.name

puts 'CREATING CUSTOMER SETTINGS FOR: Protocall Services / Visualizer'
settings = PluginVisualizer::Settings.new
CustomerSettings.create!(
  :customer_id => 1,
  :plugin_id => 1,
  :data => settings.to_json)
puts 'New settings created'

puts 'CREATING CUSTOMER SETTINGS FOR: FMC / FMC Payroll Export'
settings = PluginVisualizer::Settings.new
CustomerSettings.create!(
  :customer_id => 2,
  :plugin_id => 2,
  :data => settings.to_json)
puts 'New settings created'

puts 'CREATING CUSTOMER SETTINGS FOR: Snohomish / Snohomish Timecard Editor'
settings = PluginVisualizer::Settings.new
CustomerSettings.create!(
  :customer_id => 3,
  :plugin_id => 3,
  :data => settings.to_json)
puts 'New settings created'
