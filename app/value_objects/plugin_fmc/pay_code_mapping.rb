module PluginFMC

  class PayCodeMapping
    attr_accessor :paydesnum, :wg3, :paycode

    def initialize(a = {})
      @paydesnum = a[:paydesnum]
      @wg3       = a[:wg3]
      @paycode   = a[:paycode]
    end
  end
end
