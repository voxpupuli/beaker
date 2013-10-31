require 'yaml' unless defined?(YAML)
require 'json'
require 'net/http'

module Beaker 
  class VcloudPooled < Beaker::Hypervisor
    CHARMAP = [('a'..'z'),('0'..'9')].map{|r| r.to_a}.flatten

    def initialize(vcloud_hosts, options)
      @options = options
      @logger = options[:logger]
      @vcloud_hosts = vcloud_hosts

      raise 'You must specify a datastore for vCloud instances!' unless @options['datastore']
      raise 'You must specify a resource pool for vCloud instances!' unless @options['resourcepool']
      raise 'You must specify a folder for vCloud instances!' unless @options['folder']
    end

    def provision
      start = Time.now
      @vcloud_hosts.each_with_index do |h, i|
        if h['template'] =~ /\//
          templatefolders = h['template'].split('/')
          h['template'] = templatefolders.pop
        end

        @logger.notify "Requesting '#{h['template']}' VM from vCloud host pool"

        uri = URI.parse(@options['pooling_api']+'/vm/'+h['template'])

        http = Net::HTTP.new( uri.host, uri.port )
        request = Net::HTTP::Post.new(uri.request_uri)

        request.set_form_data({'pool' => @options['resourcepool'], 'folder' => 'foo'})

        begin
          response = http.request(request)
        rescue
          raise "Unable to connect to '#{uri}'!"
        end

        begin
          h['vmhostname'] = JSON.parse(response.body)[h.name]['hostname']
        rescue
          raise "Malformed data received from '#{uri}'!"
        end

        @logger.notify "Using available vCloud host '#{h['vmhostname']}' (#{h.name})"
      end

      @logger.notify 'Spent %.2f seconds grabbing VMs' % (Time.now - start)
    end

    def cleanup
      vm_names = @vcloud_hosts.map {|h| h['vmhostname'] }.compact
      if @vcloud_hosts.length != vm_names.length
        @logger.warn "Some hosts did not have vmhostname set correctly! This likely means VM provisioning was not successful"
      end

      start = Time.now
      vm_names.each do |name|
        @logger.notify "Handing '#{name}' back to pooling API for VM destruction"

        uri = URI.parse(@options['pooling_api']+'/vm/'+name)

        http = Net::HTTP.new( uri.host, uri.port )
        request = Net::HTTP::Delete.new(uri.request_uri)

        begin
          response = http.request(request)
        rescue
          raise "Unable to connect to '#{uri}'!"
        end
      end 

      @logger.notify "Spent %.2f seconds cleaning up" % (Time.now - start)
    end

  end
end
