require 'google/api_client'
require 'json'
require 'time'
require 'ostruct'

module Beaker
  class GoogleComputeHelper 

    class GoogleComputeError < StandardError
    end

    SLEEPWAIT = 5

    # Constants for use as request parameters.
    AUTH_URL = 'https://www.googleapis.com/auth/compute'
    API_VERSION = 'v1'
    BASE_URL = "https://www.googleapis.com/compute/#{API_VERSION}/projects/"
    CENTOS_PROJECT = 'centos-cloud'
    DEBIAN_PROJECT = 'debian-cloud'
    DEFAULT_ZONE_NAME = 'us-central1-a'
    DEFAULT_MACHINE_TYPE = 'n1-highmem-2'
    DEFAULT_DISK_SIZE = 25

    def initialize(options)
      @options = options
      @logger = options[:logger]
      try = 1
      attempts = @options[:timeout].to_i / SLEEPWAIT
      start = Time.now

      set_client(Beaker::Version::STRING)
      set_compute_api(API_VERSION, start, attempts)

      raise 'You must specify a gce_project for Google Compute Engine instances!' unless @options[:gce_project]
      raise 'You must specify a gce_keyfile for Google Compute Engine instances!' unless @options[:gce_keyfile]
      raise 'You must specify a gce_password for Google Compute Engine instances!' unless @options[:gce_password]
      raise 'You must specify a gce_email for Google Compute Engine instances!' unless @options[:gce_email]

      authenticate(@options[:gce_keyfile], @options[:gce_password], @options[:gce_email], start, attempts)
    end

    def default_zone
      BASE_URL + @options[:gce_project] + '/global/zones/' + DEFAULT_ZONE_NAME 
    end

    def default_network
      BASE_URL + @options[:gce_project] + '/global/networks/default' 
    end

    def get_platform_project(name)
      if name =~ /debian/
        return DEBIAN_PROJECT
      elsif name =~ /centos/
        return CENTOS_PROJECT
      else
        raise "Unsupported platform for Google Compute Engine: #{name}"
      end
    end

    def set_client(version)
      @client = Google::APIClient.new({:application_name => "Beaker", :application_version => version})
    end

    def set_compute_api version, start, attempts
      try = (Time.now - start) / SLEEPWAIT
      while try <= attempts
        begin
          @compute = @client.discovered_api('compute', version)
          @logger.debug("Google Compute API discovered")
          return
        rescue => e
          @logger.debug("Failed to discover Google Compute API")
          if try >= attempts 
            raise e
          end
        end
        try += 1
      end
    end

    def authenticate(keyfile, password, email, start, attempts)
      # OAuth authentication, using the service account
      key = Google::APIClient::PKCS12.load_key(keyfile, password)
      service_account = Google::APIClient::JWTAsserter.new(
          email,
          AUTH_URL,
          key)
      try = (Time.now - start) / SLEEPWAIT
      while try <= attempts
        begin
          @client.authorization = service_account.authorize
          @logger.debug("Authorized to use Google Compute")
          return
        rescue => e
          @logger.debug("Failed to authorize to use Google Compute")
          if try >= attempts 
            raise e
          end
        end
        try += 1
      end
    end

    def execute req, start, attempts
      last_error = parsed = nil
      try = (Time.now - start) / SLEEPWAIT
      while try <= attempts
        begin
          result = @client.execute(req)
          parsed = JSON.parse(result.body)
          if not result.success?
            error_code = parsed["error"] ? parsed["error"]["code"] : 0
            if error_code == 404
              raise GoogleComputeError, "Resource Not Found: #{result.body}"
            elsif error_code == 400
              raise GoogleComputeError, "Bad Request: #{result.body}"
            else
              raise GoogleComputeError, "Error attempting Google Compute API execute: #{result.body}"
            end
          end
          return parsed
        #retry errors
        rescue Faraday::Error::ConnectionFailed => e  
          @logger.debug "ConnectionFailed attempting Google Compute execute command"
          try += 1
          last_error = e
        end
      end
      #we only get down here if we've used up all our tries
      raise last_error
    end

    def get_latest_image(platform, start, attempts)
      #use the platform version numbers instead of codenames
      platform = platform.with_version_number
      #break up my platform for information
      platform_name, platform_version, platform_extra_info = platform.split('-', 3)
      #find latest image to use
      result = execute( image_list_req(platform_name), start, attempts ) 
      images = result["items"]
      #reject images of the wrong version of the given platform
      images.delete_if { |image| image['name'] !~ /^#{platform_name}-#{platform_version}/}
      #reject deprecated images
      images.delete_if { |image| image['deprecated']}
      #find a match based upon platform type
      if images.length != 1
        raise "Unable to find a single matching image for #{platform}, found #{images}"
      end
      images[0]
    end

    def get_machineType(start, attempts)
      execute( machineType_get_req, start, attempts )
    end

    def get_network(start, attempts)
      execute( network_get_req, start, attempts)
    end

    def list_instances(start, attempts)
      instances = execute( instance_list_req(), start, attempts )
      instances["items"]
    end

    def list_disks(start, attempts)
      disks = execute( disk_list_req(), start, attempts )
      disks["items"]
    end

    def list_firewalls(start, attempts)
      result = execute( firewall_list_req(), start, attempts )
      firewalls = result["items"]
      firewalls.delete_if{|f| f['name'] =~ /default-allow-internal|default-ssh/}
      firewalls
    end

    def create_firewall(name, network, start, attempts)
      execute( firewall_insert_req( name, network['selfLink'] ), start, attempts )
    end

    def create_disk(name, img, start, attempts)
      #create a new boot disk for this instance
      disk = execute( disk_insert_req( name, img['selfLink'] ), start, attempts )

      status = ''
      try = (Time.now - start) / SLEEPWAIT
      while status !~ /READY/ and try <= attempts
        begin
          disk = execute( disk_get_req( name ), start, attempts )
          status = disk['status']
        rescue GoogleComputeError => e
          @logger.debug("Waiting for #{name} disk creation")
          sleep(SLEEPWAIT)
        end
        try += 1
      end
      if status == ''
        raise "Unable to create disk #{name}"
      end
      disk
    end

    def create_instance(name, img, machineType, disk, start, attempts)
      #add a new instance of the image
      instance = execute( instance_insert_req( name, img['selfLink'], machineType['selfLink'], disk['selfLink'] ), start, attempts)
      status = ''
      try = (Time.now - start) / SLEEPWAIT
      while status !~ /RUNNING/ and try <= attempts
        begin
          instance = execute( instance_get_req( name ), start, attempts )
          status = instance['status']
        rescue GoogleComputeError => e
          @logger.debug("Waiting for #{name} instance creation")
          sleep(SLEEPWAIT)
        end
        try += 1
      end
      if status == ''
        raise "Unable to create instance #{name}"
      end
      instance
    end

    def delete_instance(name, start, attempts)
      result = execute( instance_delete_req( name ), start, attempts )
      #ensure deletion of instance
      try = (Time.now - start) / SLEEPWAIT
      while try <= attempts
        begin
          result = execute( instance_get_req( name ), start, attempts ) 
          @logger.debug("Waiting for #{name} instance deletion")
          sleep(SLEEPWAIT)
        rescue GoogleComputeError => e
          @logger.debug("#{name} instance deleted!")
          return
        end
        try += 1
      end
      @logger.debug("#{name} instance was not removed before timeout, may still exist")
    end

    def delete_disk(name, start, attempts)
      result = execute( disk_delete_req( name ), start, attempts )
      #ensure deletion of disk
      try = (Time.now - start) / SLEEPWAIT
      while try <= attempts
        begin
          disk = execute( disk_get_req( name ), start, attempts ) 
          @logger.debug("Waiting for #{name} disk deletion")
          sleep(SLEEPWAIT)
        rescue GoogleComputeError => e
          @logger.debug("#{name} disk deleted!")
          return
        end
        try += 1
      end
      @logger.debug("#{name} disk was not removed before timeout, may still exist")
    end

    def delete_firewall(name, start, attempts)
      result = execute( firewall_delete_req( name ), start, attempts )
      #ensure deletion of disk
      try = (Time.now - start) / SLEEPWAIT
      while try <= attempts
        begin
          firewall = execute( firewall_get_req( name ), start, attempts ) 
          @logger.debug("Waiting for #{name} firewall deletion")
          sleep(SLEEPWAIT)
        rescue GoogleComputeError => e
          @logger.debug("#{name} firewall deleted!")
          return
        end
        try += 1
      end
      @logger.debug("#{name} firewall was not removed before timeout, may still exist")
    end

    def image_list_req(name)
      platformProject = get_platform_project(name)
      { :api_method  => @compute.images.list, 
        :parameters  => { 'project' => platformProject } }
    end

    def disk_list_req
      { :api_method  => @compute.disks.list, 
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME } }
    end

    def disk_get_req(name)
      { :api_method  => @compute.disks.get, 
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME, 'disk' => name } }
    end

    def disk_delete_req(name)
      { :api_method  => @compute.disks.delete, 
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME, 'disk' => name } }
    end

    def disk_insert_req(name, source)
      { :api_method  => @compute.disks.insert, 
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME, 'sourceImage' => source }, 
        :body_object => { 'name' => name, 'sizeGb' => DEFAULT_DISK_SIZE } }
    end

    def firewall_get_req(name)
      { :api_method  => @compute.firewalls.get, 
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME, 'firewall' => name } }
    end

    def firewall_insert_req(name, network)
      { :api_method  => @compute.firewalls.insert, 
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME }, 
        :body_object => { 'name' => name, 
                          'allowed'=> [ { 'IPProtocol' => 'tcp', "ports" =>  [ '443', '8140', '61613' ]} ],
                          'network'=> network,
                          'sourceRanges' => [ "0.0.0.0/0" ] } }
    end

    def firewall_delete_req(name)
      { :api_method  => @compute.firewalls.delete, 
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME, 'firewall' => name } }
    end

    def firewall_list_req()
      { :api_method  => @compute.firewalls.list, 
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME } }
    end

    def network_get_req(name = 'default')
      { :api_method  => @compute.networks.get, 
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME, 'network' => name } }
    end

    def instance_list_req
      { :api_method  => @compute.instances.list, 
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME } }
    end

    def instance_get_req(name)
      { :api_method  => @compute.instances.get, 
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME, 'instance' => name } }
    end

    def instance_delete_req(name)
      { :api_method  => @compute.instances.delete, 
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME, 'instance' => name } }
    end

    def instance_insert_req(name, image, machineType, disk)
      { :api_method  => @compute.instances.insert, 
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME }, 
        :body_object => { 'name' => name, 
                          'image' => image, 
                          'zone' => default_zone, 
                          'machineType' => machineType, 
                          'disks' => [ { 'source' => disk, 
                                         'type' => 'PERSISTENT', 'boot' => 'true'} ], 
                                         'networkInterfaces' => [ { 'accessConfigs' => [{ 'type' => 'ONE_TO_ONE_NAT', 'name' => 'External NAT' }], 
                                                                    'network' => default_network } ] } }
    end

    def machineType_get_req()
      { :api_method => @compute.machine_types.get, 
        :parameters => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME, 'machineType' => @options[:gce_machine_type] || DEFAULT_MACHINE_TYPE } }
    end

  end
end
