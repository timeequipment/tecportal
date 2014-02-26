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
      log "\n\nasync method", :import_workgroups, 0
      begin

        # Connect to AoD
        aod = create_conn(@settings)
        
        # Get workgroups
        response = aod.call(
          :get_workgroups, message: {
            wGLevel: @wglevel,
            wGSortingOption: 'wgsNum' })  
        wgs = response.body[:t_ae_workgroup]

        wgcount = 0
        wgs.each do |wg|

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
      end
    end

  end
end
