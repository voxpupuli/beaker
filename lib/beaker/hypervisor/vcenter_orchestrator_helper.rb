require 'yaml' unless defined?(YAML)
require 'beaker/logger'
require 'rest-client'
require 'nokogiri'
require 'base64'
require 'json'

class VcenterOrchestratorHelper
  def initialize vInfo, verify_ssl = true
    @logger = vInfo[:logger] || Beaker::Logger.new

    @base_url = "https://#{vInfo[:server]}/api"
    @auth = 'Basic ' + Base64.encode64( "#{vInfo[:user]}:#{vInfo[:pass]}" ).chomp

    @verify_ssl = verify_ssl
  end

  def self.load_config(dot_fog = '.fog')
    # support Fog/Cloud Provisioner layout
    # (ie, someplace besides my made up conf)
    vco_credentials = nil
    if File.exists?( dot_fog )
      vco_credentials = load_fog_credentials(dot_fog)
    else
      raise ArgumentError, ".fog file '#{dot_fog}' does not exist"
    end

    return vco_credentials
  end

  def self.load_fog_credentials(dot_fog = '.fog')
    vInfo = YAML.load_file( dot_fog )

    vco_credentials = {}
    vco_credentials[:server] = vInfo[:default][:vco_server]
    vco_credentials[:user]   = vInfo[:default][:vco_username]
    vco_credentials[:pass]   = vInfo[:default][:vco_password]

    return vco_credentials
  end

  def find_workflow(wf, id)
    if id
      url = "#{@base_url}/workflows/#{id}"
    else
      wf.gsub!(/ /, '%20')
      wfs = JSON.parse(RestClient::Request.new( :method => :get, 
                                                :url => "#{@base_url}/workflows?conditions=name=#{wf}", 
                                                :headers => {:Authorization => @auth, :accept => :json}, 
                                                :verify_ssl => @verify_ssl).execute.body)
      case wfs["count"]
      when 1
        id = nil
        wfs["links"][0]["attributes"].each { |a| id = a["value"] if a["name"] == "id" }
        raise "Could not find the ID for the workflow #{wf}" if id.nil?
        url = "#{@base_url}/workflows/#{id}"
      when 0
        raise "No workflow found with the name #{wf}"
      else
        raise "More than one workflow found with the name: #{wf}\nTry specifying the workflow id instead"
      end
    end

    url
  end

  # vCO 5.1 has a bug where it won't accept JSON in, but XML is painful to parse. So send requests in XML and receive responses in JSON
  def run_workflow(url, parameters)
    params = self.params_to_xml(parameters)

    unless self.validate_wf(url, params)
      raise "The parameters supplied are not valid for this workflow"
    end

    # Execute the workflow
    response = RestClient::Request.new( :method => :post,
                                        :url => "#{url}/executions",
                                        :payload => params.to_xml,
                                        :headers => {:Authorization => @auth, :accept => :json, :content_type => :xml},
                                        :verify_ssl => @verify_ssl).execute

    # Wait until something happens
    wf_status = "RUNNING"
    while wf_status == "RUNNING"
      wf_status = self.get_wf_status(response.headers[:location])
      sleep 5
    end

    wf_status
  end

  def params_to_xml parameters
    Nokogiri::XML::Builder.new do |xml|
      xml.send("execution-context", 'xmlns' => "http://www.vmware.com/vco") {
        xml.parameters {
          parameters.each_pair do |key, value|
            type = self.javascript_class_type(value)
            xml.send("parameter", :name => key, :type => type) {
              if value.instance_of? Array
                value.each do |arr_val|
                  type = self.javascript_class_type(arr_val)
                  xml.send("#{type}", arr_val)
                end
              else
                xml.send("#{type}", value)
              end
            }
          end
        }
      }
    end
  end

  def validate_wf url, params
    response = JSON.parse(RestClient::Request.new(  :method => :post,
                                                    :url => "#{url}/presentation/instances",
                                                    :payload => params.to_xml,
                                                    :headers => {:Authorization => @auth, :accept => :json, :content_type => :xml}, 
                                                    :verify_ssl => @verify_ssl).execute.body)

    if response["valid"]
      true
    else
      @logger.notify "Vcenter Orchestrator parameter validation failed:\n #{response['validationErrors']}"
      false
    end
  end

  def get_wf_status url
    response = JSON.parse(RestClient::Request.new(:method => :get, 
                                                  :url => url, 
                                                  :headers => {:Authorization => @auth, :accept => :json, :content_type => :xml},
                                                  :verify_ssl => @verify_ssl).execute.body)

    response["state"]
  end

  def javascript_class_type value
    class_of = lambda { |object, klass| object.kind_of?(klass) }
    case
      when class_of.curry[value][String]
        return "string"
      when class_of.curry[value][Fixnum], class_of.curry[value][Float]
        return "number"
      when class_of.curry[value][FalseClass], class_of.curry[value][TrueClass]
        return "boolean"
      when class_of.curry[value][Array]
        return "Array/#{self.javascript_class_type(value[0])}"
      else
        raise "Unsupported parameter type #{value.class}"
    end
  end
end