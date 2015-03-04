require 'json'

class MockRestClient
  class Response
    attr_accessor :headers

    def body
      @body
    end

    def body=(value)
      @body = value.to_json
    end
  end

  class Request
    def initialize opts = {}
      @method = opts[:method]
      @url = opts[:url]
      @headers = opts[:headers]
      @verify_ssl = opts[:verify_ssl]
    end

    def set_response response
      @@response = response
    end

    def execute
      execute_response = MockRestClient::Response.new
      if @method == :get
        if @url =~ /workflows?conditions=name=/
          execute_response.body = {
            "count" => 1, 
            "links" => [
              "attributes" => {
                "value" => "12345678910",
                "name" => "id",
              },
            ],
          }
        end
        if @url =~ /workflows\/[0-9]*\/executions/
          execute_response.body = { "state" => @@response }
        end
      end

      if @method == :post
        if @url =~ /presentation\/instances/
          execute_response.body = { "valid" => @@response }
        end

        if @url =~ /executions/
          execute_response.headers = { :location => "#{@url}/workflows/12345678910/executions/1" }
        end
      end

      return execute_response
    end
  end
end