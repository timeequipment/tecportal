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

puts 'CREATING PLUGIN: Visualizer'
plugin = Plugin.create!(
  :id => 1, 
  :name => 'Visualizer')
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

puts 'CREATING CUSTOMER SETTINGS FOR: Protocall Services / Visualizer'
settings = PluginVisualizer::Settings.new
CustomerSettings.create!(
  :customer_id => 1,
  :plugin_id => 1,
  :data => settings.to_json)
puts 'New settings created'
