module PluginFMC

  class PayrollRecord
    include ActiveModel::Validations
    include ActiveModel::Conversion
    extend ActiveModel::Naming
    
    attr_accessor \
      :employeeid,
      :paycode,
      :hours,
      :dollars,
      :rate,
      :transactiondate,
      :trxnumber,
      :btnnext

    def to_s
      @employeeid.to_s.gsub(",", "") + "," +
      @paycode.to_s.gsub(",", "") + "," +
      @hours.round(2).to_s + "," +
      @dollars.round(2).to_s + "," +
      @rate.round(2).to_s + "," +
      @transactiondate.to_s + "," +
      @trxnumber.to_s + "," +
      @btnnext.to_s
    end
  end
end
