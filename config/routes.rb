Tecportal::Application.routes.draw do

  get "plugin_visualizer/index"

  get "plugin_visualizer/settings"

  get "plugin_visualizer/create_report"

  get "plugin_visualizer/download_report"

  devise_for :users
  
  get "tec_plugins/index" 

  get "plugin_aod_time_entry/index"

  get "plugin_aod_time_entry/settings"

  get "plugin_aod_time_entry/start"

  get "plugin_aod_time_entry/end"

  # match 'plugins_list', to: 'tecplugins#index', via: [:get]
  
  mount RailsAdmin::Engine => '/admin', :as => 'rails_admin'

  resources :dashboard

  root :to => 'home#index'

  # aod_time_entry :to => 'plugins#aod_time_entry'

  # match '/login', to: 'pages#login'

  # match '/success', to: 'pages#success'
  
  # match '/fail', to: 'pages#fail'

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
