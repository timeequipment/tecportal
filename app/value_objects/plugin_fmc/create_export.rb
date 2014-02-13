module PluginFMC

  class CreateExport 
    include ApplicationHelper

    attr_accessor :user_id, :settings, :prevend, :currend, :payperiod
    def initialize user_id,  settings,  prevend,  currend,  payperiod
      @user_id = user_id
      @settings = settings
      @prevend = prevend
      @currend = currend
      @payperiod = payperiod
    end
    
    def perform
      log "\n\nasync method", :create_export, 0
      begin

        # Connect to AoD
        progress 20, 'Connecting to AoD'
        aod = create_conn(@settings)
        
        # Get pay period chosen
        if @payperiod == "0"
          pay_period = "ppePrevious" 
        else
          pay_period = "ppeCurrent" 
        end

        # # Get all payroll employees
        # response = aod.call(
        #   :get_payroll_employees_list, message: { 
        #     payPeriodEnum: pay_period })  
        # payrollemps = response.body[:t_ae_employee_basic]
        # progress 70

        # # For each payroll employee
        # paylines = []
        # payrollemps.each do |emp|
        #   # Get their pay period summary
        #   response = aod.call(
        #     :extract_employee_period_summs_by_filekey, message: { 
        #       filekey: emp[:filekey],
        #       payPeriodEnum: pay_period,
        #       payLineStatEnum: "plsAsSaved", 
        #       calcedDataTypeEnum: "cdtNormal" })  
        #   eepaylines = response.body[:t_ae_pay_line]
        #   if eepaylines.is_a? Array
        #     paylines.concat eepaylines
        #   elsif eepaylines.is_a? Hash
        #     paylines << eepaylines
        #   end
        # end
        # progress 80

        # Get pay period summaries from AoD
        progress 40, 'Requesting pay period summaries from AoD'
        response = aod.call(
          :extract_pay_period_summaries, message: { 
            payPeriodEnum: pay_period,
            payLineStatEnum: "plsAsSaved", 
            calcedDataTypeEnum: "cdtNormal",
            noActivityInclusion: "naiSkip" })  
        paylines = response.body[:t_ae_pay_line]

        progress 80, 'Creating file'
        # Get settings
        if @settings

          # Get paycodemappings
          if @settings.paycodemappings
            mappings = JSON.parse(@settings.paycodemappings)
          end

          # Get includeumapped
          includeunmapped = true
          if @settings.includeunmapped && 
             @settings.includeunmapped == "0"
            includeunmapped = false
          end

          # Convert the paylines to payroll records
          payrecords = []
          paylines.each do |payline|
            # If there is a pay code mapping for this paydesnum
            paydesnum = payline[:pay_des_num].to_s
            wg3       = payline[:wrk_wg3].to_s
            mapping   = get_paycode_mapping(mappings, paydesnum, wg3)

            if includeunmapped 
              mapping ||= [0, 0, 0, 0]
            end

            if mapping
              p = PluginFMC::PayrollRecord.new
              p.employeeid = payline[:emp_id]
              p.paycode    = mapping[2]
              p.hours      = payline[:hours_hund].to_s.to_f
              p.dollars    = payline[:dollars].to_s.to_f
              p.rate       = payline[:wrk_rate]  .to_s.to_f
              p.transactiondate = (@payperiod == "0" ? 
                @prevend.to_s :
                @currend.to_s)
              p.trxnumber  = ''
              p.btnnext    = '1'

              if p.hours + p.dollars == 0 
                next
              end

              if p.paycode.nil? 
                p.paycode = 'Unmapped - PayDes: ' + paydesnum + ' - Wg3: ' + wg3
              end

              # Add this payroll record to our array
              payrecords << p
            end
          end
          
          # Group results by all fields, total up hours
          results = payrecords.group_by{ |a| [
            a.employeeid,
            a.paycode,
            a.rate,
            a.transactiondate ] }
              .map { |p, payrecords|
                y = PluginFMC::PayrollRecord.new
                y.employeeid      = p[0].to_s
                y.paycode         = p[1].to_s
                y.hours           = payrecords.sum { |b| b.hours.to_f }
                y.dollars         = payrecords.sum { |b| b.dollars.to_f }
                y.rate            = p[2].to_s.to_f
                y.transactiondate = p[3].to_s
                y.trxnumber = ''
                y.btnnext = '1'
                y } 

          # Create header for payroll records
          header = 'Employee ID,Pay Code,Amount,Rate,Transaction Date,Trx Number,Btn Next'

          # Create file, from header and payroll records
          cache_save @user_id, 'fmc_export', header + "\n" + results.join("\n")
        end

      rescue Exception => exc
        log 'exception', exc.message
        log 'exception backtrace', exc.backtrace
      ensure
        progress 100, ''
      end
    end

    def after(job)
    end

    private

    def progress percent, status
      cache_save @user_id, 'fmc_progress', percent.to_s
      cache_save @user_id, 'fmc_status', status
      sleep 2 # Wait to allow user to see status
    end

    def get_paycode_mapping(mappings, paydesnum, wg3)
      mappings.each do |mapping|
        if mapping[0] == paydesnum && mapping[1] == wg3
          return mapping
        end
      end
      nil
    end

  end
end
