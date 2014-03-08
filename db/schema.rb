# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20140306015422) do

  create_table "caches", :force => true do |t|
    t.string   "key"
    t.text     "value"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.integer  "user_id"
  end

  create_table "customer_settings", :force => true do |t|
    t.integer  "customer_id"
    t.integer  "plugin_id"
    t.text     "data"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  add_index "customer_settings", ["customer_id", "plugin_id"], :name => "index_customer_settings_on_customer_id_and_plugin_id"

  create_table "customers", :force => true do |t|
    t.string   "name"
    t.string   "description"
    t.integer  "status"
    t.string   "website"
    t.string   "mainphone"
    t.string   "fax"
    t.string   "address1"
    t.string   "address2"
    t.string   "city"
    t.string   "state"
    t.string   "zip"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  add_index "customers", ["id"], :name => "index_customers_on_id", :unique => true

  create_table "customers_plugins", :force => true do |t|
    t.integer "customer_id"
    t.integer "plugin_id"
  end

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",   :default => 0, :null => false
    t.integer  "attempts",   :default => 0, :null => false
    t.text     "handler",                   :null => false
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at",                :null => false
    t.datetime "updated_at",                :null => false
  end

  add_index "delayed_jobs", ["priority", "run_at"], :name => "delayed_jobs_priority"

  create_table "plugins", :force => true do |t|
    t.integer  "type"
    t.string   "name"
    t.string   "description"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  add_index "plugins", ["id"], :name => "index_plugins_on_id", :unique => true

  create_table "psvm_cust_patterns", :force => true do |t|
    t.integer  "wg_level"
    t.integer  "wg_num"
    t.string   "day1"
    t.string   "day2"
    t.string   "day3"
    t.string   "day4"
    t.string   "day5"
    t.string   "day6"
    t.string   "day7"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "psvm_cust_patterns", ["wg_level", "wg_num"], :name => "psvm_cust_patterns_wg_level_wg_num"

  create_table "psvm_emp_customers", :force => true do |t|
    t.string  "emp_id"
    t.integer "wg_level"
    t.integer "wg_num"
  end

  add_index "psvm_emp_customers", ["emp_id", "wg_level", "wg_num"], :name => "index_psvm_emp_customers_on_emp_id_and_wg_level_and_wg_num"

  create_table "psvm_emp_workgroups", :force => true do |t|
    t.integer "psvm_emp_id"
    t.integer "psvm_workgroup_id"
  end

  add_index "psvm_emp_workgroups", ["psvm_emp_id", "psvm_workgroup_id"], :name => "index_psvm_emp_workgroups_on_psvm_emp_id_and_psvm_workgroup_id"

  create_table "psvm_emps", :force => true do |t|
    t.integer  "filekey"
    t.string   "last_name"
    t.string   "first_name"
    t.string   "initial"
    t.string   "emp_id"
    t.string   "ssn"
    t.string   "badge"
    t.integer  "active_status"
    t.datetime "hire_date"
    t.integer  "wg1"
    t.integer  "wg2"
    t.integer  "wg3"
    t.integer  "wg4"
    t.integer  "wg5"
    t.integer  "wg6"
    t.integer  "wg7"
    t.float    "current_rate"
    t.integer  "pay_type_id"
    t.integer  "pay_class_id"
    t.integer  "sch_patt_id"
    t.integer  "hourly_status_id"
    t.integer  "clock_group_id"
    t.datetime "birth_date"
    t.string   "custom1"
    t.string   "custom2"
    t.string   "custom3"
    t.string   "custom4"
    t.string   "custom5"
    t.string   "custom6"
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
  end

  add_index "psvm_emps", ["filekey"], :name => "psvm_scheds_filekey"

  create_table "psvm_scheds", :force => true do |t|
    t.integer  "filekey"
    t.date     "sch_date"
    t.datetime "sch_start_time"
    t.datetime "sch_end_time"
    t.integer  "sch_hours"
    t.float    "sch_rate"
    t.float    "sch_hours_hund"
    t.integer  "sch_type"
    t.integer  "sch_style"
    t.integer  "sch_patt_id"
    t.integer  "benefit_id"
    t.integer  "pay_des_id"
    t.integer  "sch_wg1"
    t.integer  "sch_wg2"
    t.integer  "sch_wg3"
    t.integer  "sch_wg4"
    t.integer  "sch_wg5"
    t.integer  "sch_wg6"
    t.integer  "sch_wg7"
    t.integer  "unique_id"
    t.datetime "created_at",     :null => false
    t.datetime "updated_at",     :null => false
  end

  add_index "psvm_scheds", ["filekey", "sch_date", "sch_start_time"], :name => "psvm_scheds_filekey_sch_date_sch_start_time"

  create_table "psvm_workgroups", :force => true do |t|
    t.integer  "wg_level"
    t.integer  "wg_num"
    t.string   "wg_code"
    t.string   "wg_name"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "psvm_workgroups", ["wg_num"], :name => "psvm_workgroups_wg_num"

  create_table "sessions", :force => true do |t|
    t.string   "session_id", :null => false
    t.text     "data"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"
  add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"

  create_table "user_settings", :force => true do |t|
    t.integer  "user_id"
    t.integer  "plugin_id"
    t.text     "data"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "user_settings", ["user_id", "plugin_id"], :name => "index_user_settings_on_user_id_and_plugin_id"

  create_table "users", :force => true do |t|
    t.integer  "customer_id"
    t.string   "name",                   :default => "",    :null => false
    t.string   "email",                  :default => "",    :null => false
    t.string   "encrypted_password",     :default => "",    :null => false
    t.boolean  "sys_admin",              :default => false, :null => false
    t.boolean  "customer_admin",         :default => false, :null => false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          :default => 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.string   "password_salt"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email"
    t.integer  "failed_attempts",        :default => 0
    t.string   "unlock_token"
    t.datetime "locked_at"
    t.string   "authentication_token"
    t.datetime "created_at",                                :null => false
    t.datetime "updated_at",                                :null => false
  end

  add_index "users", ["email"], :name => "index_users_on_email", :unique => true
  add_index "users", ["reset_password_token"], :name => "index_users_on_reset_password_token", :unique => true

end
