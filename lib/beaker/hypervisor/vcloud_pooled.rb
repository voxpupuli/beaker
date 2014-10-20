require 'yaml' unless defined?(YAML)
require 'json'
require 'net/http'

module Beaker
  class VcloudPooled < Beaker::Hypervisor
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

    def initialize(vcloud_hosts, options)
      @options = options
      @logger = options[:logger]
      @hosts = vcloud_hosts

      raise 'You must specify a datastore for vCloud instances!' unless @options['datastore']
      raise 'You must specify a resource pool for vCloud instances!' unless @options['resourcepool']
      raise 'You must specify a folder for vCloud instances!' unless @options['folder']
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

    def provision
      start = Time.now
      try = 1
      @hosts.each_with_index do |h, i|
        if not h['template']
          raise ArgumentError, "You must specify a template name for #{h}"
        end
        if h['template'] =~ /\//
          templatefolders = h['template'].split('/')
          h['template'] = templatefolders.pop
        end

        @logger.notify "Requesting '#{h['template']}' VM from vCloud host pool"

        begin
          uri = URI.parse(get_template_url(@options['pooling_api'], h['template']))

          http = Net::HTTP.new( uri.host, uri.port )
          request = Net::HTTP::Post.new(uri.request_uri)

          request.set_form_data({'pool' => @options['resourcepool'], 'folder' => 'foo'})

          attempts = @options[:timeout].to_i / 5
          response = http.request(request)
          parsed_response = JSON.parse(response.body)
          if parsed_response[h['template']] && parsed_response[h['template']]['ok'] && parsed_response[h['template']]['hostname']
            hostname = parsed_response[h['template']]['hostname']
            domain = parsed_response['domain']
            h['vmhostname'] = domain ? "#{hostname}.#{domain}" : hostname
          else
            raise "VcloudPooled.provision - no vCloud host free for #{h.name} in pool"
          end
        rescue JSON::ParserError, RuntimeError, *SSH_EXCEPTIONS => e
          if try <= attempts
            sleep 5
            try += 1
            retry
          end
          report_and_raise(@logger, e, 'vCloudPooled.provision')
        end

        @logger.notify "Using available vCloud host '#{h['vmhostname']}' (#{h.name})"
      end

      @logger.notify 'Spent %.2f seconds grabbing VMs' % (Time.now - start)
    end

    def cleanup
      vm_names = @hosts.map {|h| h['vmhostname'] }.compact
      if @hosts.length != vm_names.length
        @logger.warn "Some hosts did not have vmhostname set correctly! This likely means VM provisioning was not successful"
      end

      start = Time.now
      vm_names.each do |name|
        @logger.notify "Handing '#{name}' back to pooling API for VM destruction"

        uri = URI.parse(get_template_url(@options['pooling_api'], name))

        http = Net::HTTP.new( uri.host, uri.port )
        request = Net::HTTP::Delete.new(uri.request_uri)

        begin
          response = http.request(request)
        rescue *SSH_EXCEPTIONS => e
          report_and_raise(@logger, e, 'vCloudPooled.cleanup (http.request)')
        end
      end

      @logger.notify "Spent %.2f seconds cleaning up" % (Time.now - start)
    end

  end
end
