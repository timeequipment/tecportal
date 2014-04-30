module PluginBambooHr

  class Bamboo 
    include HTTParty
    base_uri 'https://api.bamboohr.com/api/gateway.php'

    # Uncomment to output entire HTTP request and response
    # debug_output $stdout
  
    def initialize(company, key)
      @company = company
      @options = { 
        headers: { "Accept" => "application/json" }, 
        basic_auth: { username: key, password: 'x' } }
    end

    def get_fields
      response = self.class.get("/#{ @company }/v1/meta/fields", @options)
      response["fields"]
    end

    def get_employee(empid, fields = "lastName,firstName")
      response = self.class.get("/#{ @company }/v1/employees/#{ empid }?fields=#{ fields }", @options)
      response
    end

    def get_employees
      response = self.class.get("/#{ @company }/v1/employees/directory", @options)
      response["employees"]
    end

    def get_employees_changed(since)
      response = self.class.get("/#{ @company }/v1/employees/changed?since=#{ since }", @options)
      response["changeList"]["employee"]
    end
    
  end
end
