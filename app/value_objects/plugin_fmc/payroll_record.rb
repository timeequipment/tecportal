module PluginFMC

  class PayrollRecord
    attr_accessor \
      :employeeid,
      :paycode,
      :hours,
      :rate,
      :transactiondate,
      :trxnumber,
      :btnnext

    def to_s
      @employeeid.to_s.gsub(",", "") + "," +
      @paycode.to_s.gsub(",", "") + "," +
      @hours.round(2).to_s + "," +
      @rate.round(2).to_s + "," +
      @transactiondate.to_s + "," +
      @trxnumber.to_s + "," +
      @btnnext.to_s
    end
  end
end
