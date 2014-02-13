# Execute all jobs realtime (only in debug env)
Delayed::Worker.delay_jobs = true # Rails.env.production?

# 5 second delay before starting jobs
# Delayed::Worker.sleep_delay = 5 

# Use the Rails log
Delayed::Worker.logger = Rails.logger
