require 'yaml' unless defined?(YAML)
require 'json'
require 'net/http'

module Beaker
  class Vmpooler < Beaker::Hypervisor
    SSH_EXCEPTIONS = [
      SocketError,
      Timeout::Error,
      Errno::ETIMEDOUT,
      Errno::EHOSTDOWN,
      Errno::EHOSTUNREACH,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::ENETUNREACH,
    ]

    attr_reader :options, :logger, :hosts, :credentials

    def initialize(vmpooler_hosts, options)
      @options = options
      @logger = options[:logger]
      @hosts = vmpooler_hosts
      @credentials = load_credentials(@options[:dot_fog])
    end

    def load_credentials(dot_fog = '.fog')
      creds = {}

      if fog = read_fog_file(dot_fog)
        if fog[:default] && fog[:default][:vmpooler_token]
          creds[:vmpooler_token] = fog[:default][:vmpooler_token]
        else
          @logger.warn "Credentials file (#{dot_fog}) is missing a :default section with a :vmpooler_token value; proceeding without authentication"
        end
      else
        @logger.warn "Credentials file (#{dot_fog}) is empty; proceeding without authentication"
      end

      creds

    rescue Errno::ENOENT
      @logger.warn "Credentials file (#{dot_fog}) not found; proceeding without authentication"
      creds
    rescue TypeError
      @logger.warn "Errors in credentials file (#{dot_fog}); missing a :default section; proceeding without authentication"
      creds
    end

    def read_fog_file(dot_fog = '.fog')
      YAML.load_file(dot_fog)
    end

    def check_url url
      begin
        URI.parse(url)
      rescue
        return false
      end
      true
    end

    def get_template_url pooling_api, template
      if not check_url(pooling_api)
        raise ArgumentError, "Invalid pooling_api URL: #{pooling_api}"
      end
      scheme = ''
      if not URI.parse(pooling_api).scheme
        scheme = 'http://'
      end
      #check that you have a valid uri
      template_url = scheme + pooling_api + '/vm/' + template
      if not check_url(template_url)
        raise ArgumentError, "Invalid full template URL: #{template_url}"
      end
      template_url
    end

    # Override host tags with presets
    # @param [Beaker::Host] host Beaker host
    # @return [Hash] Tag hash
    def add_tags(host)
      host[:host_tags].merge(
          {
              'beaker_version'    => Beaker::Version::STRING,
              'jenkins_build_url' => @options[:jenkins_build_url],
              'department'        => @options[:department],
              'project'           => @options[:project],
              'created_by'        => @options[:created_by]
          })
    end

    # Get host info hash from parsed json response
    # @param [Hash] parsed_response hash
    # @param [String] template string
    # @return [Hash] Host info hash
    def get_host_info(parsed_response, template)
      parsed_response[template]
    end

    def provision
      request_payload = {}
      start = Time.now

      @hosts.each_with_index do |h, i|
        if not h['template']
          raise ArgumentError, "You must specify a template name for #{h}"
        end
        if h['template'] =~ /\//
          templatefolders = h['template'].split('/')
          h['template'] = templatefolders.pop
        end

        request_payload[h['template']] = (request_payload[h['template']].to_i + 1).to_s
      end

      last_wait, wait = 0, 1
      waited = 0 #the amount of time we've spent waiting for this host to provision
      begin
        uri = URI.parse(@options['pooling_api'] + '/vm/')

        http = Net::HTTP.new(uri.host, uri.port)
        request = Net::HTTP::Post.new(uri.request_uri)

        if @credentials[:vmpooler_token]
          request['X-AUTH-TOKEN'] = @credentials[:vmpooler_token]
          @logger.notify "Requesting VM set from vmpooler (with authentication token)"
        else
          @logger.notify "Requesting VM set from vmpooler"
        end

        request_payload_json = request_payload.to_json
        @logger.trace( "Request payload json: #{request_payload_json}" )
        request.body = request_payload_json

        response = http.request(request)
        parsed_response = JSON.parse(response.body)
        @logger.trace( "Response parsed json: #{parsed_response}" )

        if parsed_response['ok']
          domain = parsed_response['domain']
          request_payload = {}

          @hosts.each_with_index do |h, i|
            # If the requested host template is not available on vmpooler
            host_template = h['template']
            if get_host_info(parsed_response, host_template).nil?
              request_payload[host_template] ||= 0
              request_payload[host_template] += 1
              next
            end
            if parsed_response[h['template']]['hostname'].is_a?(Array)
              hostname = parsed_response[host_template]['hostname'].shift
            else
              hostname = parsed_response[host_template]['hostname']
            end

            h['vmhostname'] = domain ? "#{hostname}.#{domain}" : hostname

            @logger.notify "Using available host '#{h['vmhostname']}' (#{h.name})"
          end
          unless request_payload.empty?
            raise "Vmpooler.provision - requested VM templates #{request_payload.keys} not available"
          end
        else
          raise "Vmpooler.provision - response from pooler not ok. Requested host set #{request_payload.keys} not available in pooler.\n#{parsed_response}"
        end
      rescue JSON::ParserError, RuntimeError, *SSH_EXCEPTIONS => e
        @logger.debug "Failed vmpooler provision: #{e.class} : #{e.message}"
        if waited <= @options[:timeout].to_i
          @logger.debug("Retrying provision for vmpooler host after waiting #{wait} second(s)")
          sleep wait
          waited += wait
          last_wait, wait = wait, last_wait + wait
        retry
        end
        report_and_raise(@logger, e, 'Vmpooler.provision')
      end

      @logger.notify 'Spent %.2f seconds grabbing VMs' % (Time.now - start)

      start = Time.now
      @logger.notify 'Tagging vmpooler VMs'

      @hosts.each_with_index do |h, i|
        begin
          uri = URI.parse(@options[:pooling_api] + '/vm/' + h['vmhostname'].split('.')[0])

          http = Net::HTTP.new(uri.host, uri.port)
          request = Net::HTTP::Put.new(uri.request_uri)

          # merge pre-defined tags with host tags
          request.body = { 'tags' => add_tags(h) }.to_json

          response = http.request(request)
        rescue RuntimeError, Errno::EINVAL, Errno::ECONNRESET, EOFError,
               Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, *SSH_EXCEPTIONS => e
          @logger.notify "Failed to connect to vmpooler for tagging!"
        end

        begin
          parsed_response = JSON.parse(response.body)

          unless parsed_response['ok']
            @logger.notify "Failed to tag host '#{h['vmhostname']}'!"
          end
        rescue JSON::ParserError => e
            @logger.notify "Failed to tag host '#{h['vmhostname']}'! (failed with #{e.class})"
        end
      end

      @logger.notify 'Spent %.2f seconds tagging VMs' % (Time.now - start)
    end

    def cleanup
      vm_names = @hosts.map {|h| h['vmhostname'] }.compact
      if @hosts.length != vm_names.length
        @logger.warn "Some hosts did not have vmhostname set correctly! This likely means VM provisioning was not successful"
      end

      start = Time.now
      vm_names.each do |name|
        @logger.notify "Handing '#{name}' back to vmpooler for VM destruction"

        uri = URI.parse(get_template_url(@options['pooling_api'], name))

        http = Net::HTTP.new( uri.host, uri.port )
        request = Net::HTTP::Delete.new(uri.request_uri)

        if @credentials[:vmpooler_token]
          request['X-AUTH-TOKEN'] = @credentials[:vmpooler_token]
        end

        begin
          response = http.request(request)
        rescue *SSH_EXCEPTIONS => e
          report_and_raise(@logger, e, 'Vmpooler.cleanup (http.request)')
        end
      end

      @logger.notify "Spent %.2f seconds cleaning up" % (Time.now - start)
    end

  end
end
