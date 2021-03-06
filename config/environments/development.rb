Tecportal::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Don't buffer stdout (for foreman logging)
  $stdout.sync = true

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Load assets from app/assets instead of public/assets
  # (Apache or nginx will already do this)
  config.serve_static_assets = false

  # Do not compress assets
  config.assets.compress = false

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Expands the lines which load the assets
  # Set this to false to compile and cache assets 
  # on first request after server is started
  config.assets.debug = false;

  #Missing host to link to! Please provide the :host parameter, set default_url_options[:host], or set :only_path to true
  config.action_mailer.default_url_options = { :host => 'localhost:5000' }

  config.action_mailer.smtp_settings = {
    address: "smtp.gmail.com",
    port: 587,
    domain: "example.com",
    authentication: "plain",
    enable_starttls_auto: true,
    user_name: ENV["GMAIL_USERNAME"],
    password: ENV["GMAIL_PASSWORD"]
  }

end
