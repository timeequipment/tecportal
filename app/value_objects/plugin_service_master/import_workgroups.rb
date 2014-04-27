module PluginServiceMaster

  class ImportWorkgroups
    include ApplicationHelper

    attr_accessor :user_id, :settings, :wglevel
    def initialize user_id,  settings,  wglevel
      @user_id = user_id
      @settings = settings
      @wglevel = wglevel
    end
    
    def perform
      log "\n\nasync method", __method__, 0
      begin

        # Connect to AoD
        progress 20, 'Connecting to AoD'
        aod = create_conn(@settings)
        
        # Get workgroups
        progress 40, 'Getting workgroups'
        response = aod.call(
          :get_workgroups, message: {
            wGLevel: @wglevel,
            wGSortingOption: 'wgsNum' })  
        wgs = response.body[:t_ae_workgroup]

        wgcount = 0
        wgs.each_with_index do |wg, i|

          progress 40 + (60 * i / wgs.count), "Importing #{ i } of #{ wgs.count }"

          # Insert or Update this workgroup
          my_wg = PsvmWorkgroup.where(
            wg_level: wg[:wg_level], 
            wg_num:   wg[:wg_num]).first_or_initialize
          my_wg.wg_level  = wg[:wg_level]  unless wg[:wg_level].is_a? Hash
          my_wg.wg_num    = wg[:wg_num]    unless wg[:wg_num].is_a? Hash
          my_wg.wg_code   = wg[:wg_code]   unless wg[:wg_num].is_a? Hash
          my_wg.wg_name   = wg[:wg_name]   unless wg[:wg_num].is_a? Hash
          my_wg.save
          wgcount += 1
        end

        # Log how many updated
        log 'Updated workgroups:', wgcount

      rescue Exception => exc
        log 'exception', exc.message
        log 'exception backtrace', exc.backtrace
      ensure
        progress 100, ''
      end      
    end

    def progress percent, status
      cache_save @user_id, 'svm_progress', percent.to_s
      cache_save @user_id, 'svm_status', status
      sleep 2 # Wait to allow user to see status
    end

  end
end