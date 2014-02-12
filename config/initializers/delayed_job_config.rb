# Execute all jobs realtime (only in debug env)
Delayed::Worker.delay_jobs = false # !(Rails.env.test? || Rails.env.development?)

# 5 second delay before starting jobs
Delayed::Worker.sleep_delay = 5

# Use the Rails log
Delayed::Worker.logger = Rails.logger

# Log realtime
# Delayed::Worker.logger.auto_flushing = true