require 'google/api_client'
require 'json'
require 'time'
require 'ostruct'

module Beaker
  class GoogleCompute < Beaker::Hypervisor

    class GoogleComputeError < StandardError
    end

    SLEEPWAIT = 5
    #number of hours before an instance is considered a zombie
    ZOMBIE = 3

    # Constants for use as request parameters.
    AUTH_URL = 'https://www.googleapis.com/auth/compute'
    API_VERSION = 'v1'
    BASE_URL = "https://www.googleapis.com/compute/#{API_VERSION}/projects/"
    CENTOS_PROJECT = 'centos-cloud'
    DEBIAN_PROJECT = 'debian-cloud'
    DEFAULT_ZONE_NAME = 'us-central1-a'
    DEFAULT_MACHINE_TYPE = 'n1-highmem-2'
    DEFAULT_DISK_SIZE = 25

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

    def initialize(google_hosts, options)
      @options = options
      @logger = options[:logger]
      @google_hosts = google_hosts
      @firewall = ''
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

    def request_body name, image, machineType, project
      {
        'name' => name,
        'image' => image,
        'zone' => default_zone,
        'machineType' => machineType,
        'networkInterfaces' => [{ 'network' => default_network }]
      }
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

    def allow_root_login host
      @logger.debug "Update /etc/ssh/sshd_config to allow root login"
      host.exec(Command.new("sudo su -c \"sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config\""), {:pty => true})
      #restart sshd
      if host['platform'] =~ /debian|ubuntu/
        host.exec(Command.new("sudo su -c \"service ssh restart\""), {:pty => true})
      elsif host['platform'] =~ /centos|el-|redhat|fedora/
        host.exec(Command.new("sudo su -c \"service sshd restart\""), {:pty => true})
      else
        raise "Attempting to update ssh on non-supported platform: #{host.name}: #{host['platform']}"
      end
    end

    def disable_se_linux_and_firewall host
      if host['platform'] =~ /centos/
        @logger.debug("Disabling se_linux on #{host.name}")
        host.exec(Command.new("sudo su -c \"setenforce 0\""), {:pty => true})
        host.exec(Command.new("sudo su -c \"/etc/init.d/iptables stop\""), {:pty => true})
      end
    end

    def get_latest_image(platform, start, attempts)
      #use the platform version numbers instead of codenames
      platform = use_version_number(platform)
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
        raise "Unable to find a single matching image for #{host[:platform]}, found #{images}"
      end
      images[0]
    end

    def provision
      try = 1
      attempts = @options[:timeout].to_i / SLEEPWAIT
      start = Time.now

      #get machineType resource, used my all instances
      machineType = execute( machineType_get_req, start, attempts )

      #set firewall to open pe ports
      network = execute( network_get_req, start, attempts)
      @firewall = generate_host_name
      execute( firewall_insert_req( @firewall, network['selfLink'] ), start, attempts )

      @logger.debug("Created firewall #{@firewall}")


      @google_hosts.each do |host|
        img = get_latest_image(host[:platform], start, attempts)

        #create boot disk name
        host['diskname'] = generate_host_name
        #create a new boot disk for this instance
        disk = execute( disk_insert_req( host['diskname'], img['selfLink'] ), start, attempts )

        status = ''
        try = (Time.now - start) / SLEEPWAIT
        while status !~ /READY/ and try <= attempts 
          begin
            disk = execute( disk_get_req( host['diskname'] ), start, attempts )
            status = disk['status']
          rescue GoogleComputeError => e
            @logger.debug("Waiting for #{host.name}: #{host['diskname']} disk creation")
            sleep(SLEEPWAIT)
          end
          try += 1
        end
        if status == ''
          raise "Unable to create disk #{host.name}: #{host['diskname']}"
        end
        @logger.debug("Created disk #{host.name}: #{host['diskname']}")

        #create new host name
        host['vmhostname'] = generate_host_name
        #add a new instance of the image
        instance = execute( instance_insert_req( host['vmhostname'], img['selfLink'], machineType['selfLink'], disk['selfLink'] ), start, attempts)
        status = ''
        try = (Time.now - start) / SLEEPWAIT
        while status !~ /RUNNING/ and try <= attempts
          begin
            instance = execute( instance_get_req( host['vmhostname'] ), start, attempts ) 
            status = instance['status']
          rescue GoogleComputeError => e
            @logger.debug("Waiting for #{host.name}: #{host['vmhostname']} instance creation")
            sleep(SLEEPWAIT)
          end
          try += 1
        end
        if status == ''
          raise "Unable to create instance #{host.name}: #{host['vmhostname']}"
        end
        @logger.debug("Created instance #{host.name}: #{host['vmhostname']}")

        #get ip for this host
        host['ip'] = instance['networkInterfaces'][0]['accessConfigs'][0]['natIP']

        #configure ssh
        default_user = host['user']
        host['user'] = 'google_compute'

        disable_se_linux_and_firewall(host)
        copy_ssh_to_root(host)
        allow_root_login(host)
        host['user'] = default_user

        #shut down connection, will reconnect on next exec
        host.close

        @logger.debug("Instance ready: #{host['vmhostname']} for #{host.name}}")
      end
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

    def cleanup()
      attempts = @options[:timeout].to_i / SLEEPWAIT
      start = Time.now

      delete_firewall(@firewall, start, attempts) 

      @google_hosts.each do |host|
        delete_instance(host['vmhostname'], start, attempts)
        @logger.debug("Deleted instance #{host['vmhostname']} for #{host.name}")
        delete_disk(host['diskname'], start, attempts)
        @logger.debug("Deleted disk #{host['diskname']} for #{host.name}")
      end

    end

    def kill_zombies(max_age = ZOMBIE)
      now = start = Time.now
      attempts = @options[:timeout].to_i / SLEEPWAIT

      #get rid of old instances 
      result = execute( instance_list_req(), start, attempts ) 
      instances = result["items"]
      if instances
        instances.each do |instance|
          created = Time.parse(instance['creationTimestamp'])
          alive = (now - created ) /60 /60
          if alive >= max_age
            #kill it with fire!
            @logger.debug("Deleting zombie instance #{instance['name']}")
            delete_instance( instance['name'], start, attempts )
          end
        end
      else 
        @logger.debug("No zombie instances found")
      end
      #get rid of old disks
      result = execute( disk_list_req(), start, attempts ) 
      disks = result["items"]
      if disks
        disks.each do |disk|
          created = Time.parse(disk['creationTimestamp'])
          alive = (now - created ) /60 /60
          if alive >= max_age
            #kill it with fire!
            @logger.debug("Deleting zombie disk #{disk['name']}")
            delete_disk( disk['name'], start, attempts )
          end
        end
      else
        @logger.debug("No zombie disks found")
      end
      #get rid of non-default firewalls
      result = execute( firewall_list_req(), start, attempts ) 
      firewalls = result["items"]
      firewalls.delete_if{|f| f['name'] =~ /default-allow-internal|default-ssh/}

      if firewalls and not firewalls.empty?
        firewalls.each do |firewall|
          @logger.debug("Deleting non-default firewall #{firewall['name']}")
          delete_firewall( firewall['name'], start, attempts )
        end
      else
        @logger.debug("No zombie firewalls found")
      end

    end

  end
end
