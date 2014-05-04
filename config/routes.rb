Tecportal::Application.routes.draw do

  # BambooHR plugin
  get 'plugin_bamboo_hr/index'
  get 'plugin_bamboo_hr/settings'
  get 'plugin_bamboo_hr/save_settings'
  get 'plugin_bamboo_hr/import_employees'
  get 'plugin_bamboo_hr/progress'

  # ServiceMaster plugin
  get 'plugin_service_master/index'
  get 'plugin_service_master/settings'
  post 'plugin_service_master/save_settings'
  get 'plugin_service_master/employee_list'
  get 'plugin_service_master/customer_list'
  get 'plugin_service_master/get_employee'
  post 'plugin_service_master/save_employee'
  get 'plugin_service_master/get_customer'
  post 'plugin_service_master/save_customer'
  get 'plugin_service_master/import_employees'
  get 'plugin_service_master/import_workgroups'
  post 'plugin_service_master/save_schedule'
  post 'plugin_service_master/delete_schedule'
  get 'plugin_service_master/team_filter'
  get 'plugin_service_master/cust_filter'
  get 'plugin_service_master/next_week'
  get 'plugin_service_master/prev_week'
  get 'plugin_service_master/export_scheds'
  get 'plugin_service_master/generate_scheds'
  get 'plugin_service_master/progress'

  # Snohomish plugin
  get 'plugin_snohomish/index'
  get 'plugin_snohomish/settings'
  post 'plugin_snohomish/save_settings'
  get 'plugin_snohomish/round_hours'

  # FMC plugin
  get 'plugin_fmc/index'
  get 'plugin_fmc/settings'
  post 'plugin_fmc/save_settings'
  get 'plugin_fmc/create_export'
  get 'plugin_fmc/progress'
  get 'plugin_fmc/finish'
  get 'plugin_fmc/download_file'

  # Visualizer plugin
  get 'plugin_visualizer/index'
  get 'plugin_visualizer/settings'
  post 'plugin_visualizer/save_settings'
  get 'plugin_visualizer/create_report'
  get 'plugin_visualizer/download_report'

  # AoD Time Entry plugin  
  get 'plugin_aod_time_entry/index'
  get 'plugin_aod_time_entry/settings'
  get 'plugin_aod_time_entry/start'
  get 'plugin_aod_time_entry/end'

  # Tec Plugins
  get 'tec_plugins/list' 

  # Devise
  devise_for :users; 

  # RailsAdmin
  mount RailsAdmin::Engine => '/admin', :as => 'rails_admin'

  # Home
  get 'home/dashboard' 
  root :to => 'home#index'

  # The priority is based upon order of creation:
  # first created -> highest priority. 

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => 'welcome#index'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
end
