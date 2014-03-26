module PluginServiceMaster

  class ExportToAod 
    include ApplicationHelper

    attr_accessor :user_id, :settings, :scheds
    def initialize user_id,  settings,  scheds
      @user_id = user_id
      @settings = settings
      @scheds = scheds
    end
    
    def perform
      log "\n\nasync method", __method__, 0
      begin

        # Connect to AoD
        progress 20, 'Connecting to AoD'
        aod = create_conn(@settings)

        # Send scheds to AoD one at a time
        
        progress 40, 'doing something 1'
        sleep 3
        progress 60, 'doing somethign 2'
        sleep 3
        progress 80, 'doing something 3'
        sleep 3
        
      rescue Exception => exc
        log 'exception', exc.message
        log 'exception backtrace', exc.backtrace
      ensure
        progress 100, ''
      end
    end

    private

    def progress percent, status
      cache_save @user_id, 'svm_progress', percent.to_s
      cache_save @user_id, 'svm_status', status
      sleep 2 # Wait to allow user to see status
    end

  end
end
