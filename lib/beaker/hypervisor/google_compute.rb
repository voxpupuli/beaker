require 'google/api_client'
require 'json'
require 'time'
require 'ostruct'

module Beaker
  class GoogleCompute < Beaker::Hypervisor
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
      try = 1
      attempts = @options[:timeout].to_i / SLEEPWAIT
      start = Time.now

      set_client(@options[:v])
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

    def execute req
      result = @client.execute(req)
      parsed = JSON.parse(result.body)
      if not result.success?
        error_code = parsed["error"] ? parsed["error"]["code"] : 0
        if error_code == 404
          raise "Resource Not Found: #{result.body}"
        elsif error_code == 400
          raise "Bad Request: #{result.body}"
        else
          raise "Error attempting Google Compute API execute: #{result.body}"
        end
      end
      parsed
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

    def get_latest_image(platform)
      #break up my platform for information
      platform_name, platform_version, platform_extra_info = platform.split('-', 3)
      #find latest image to use
      result = execute( image_list_req(platform_name) ) 
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
      machineType = execute( machineType_get_req )

      @google_hosts.each do |host|
        img = get_latest_image(host[:platform])

        #create boot disk name
        host['diskname'] = generate_host_name
        #create a new boot disk for this instance
        disk = execute( disk_insert_req( host['diskname'], img['selfLink'] ) )

        status = ''
        try = (Time.now - start) / SLEEPWAIT
        while status !~ /READY/ and try <= attempts 
          begin
            disk = execute( disk_get_req( host['diskname'] ) )
            status = disk['status']
          rescue
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
        instance = execute( instance_insert_req( host['vmhostname'], img['selfLink'], machineType['selfLink'], disk['selfLink'] ) )
        status = ''
        try = (Time.now - start) / SLEEPWAIT
        while status !~ /RUNNING/ and try <= attempts
          begin
            instance = execute( instance_get_req( host['vmhostname'] ) ) 
            status = instance['status']
          rescue
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
      result = execute( instance_delete_req( name ) )
      #ensure deletion of instance
      try = (Time.now - start) / SLEEPWAIT
      while try <= attempts
        begin
          result = execute( instance_get_req( name ) ) 
          @logger.debug("Waiting for #{name} instance deletion")
          sleep(SLEEPWAIT)
        rescue
          @logger.debug("#{name} instance deleted!")
          return
        end
        try += 1
      end
      @logger.debug("#{name} instance was not removed before timeout, may still exist")
    end

    def delete_disk(name, start, attempts)
      result = execute( disk_delete_req( name ) )
      #ensure deletion of disk
      try = (Time.now - start) / SLEEPWAIT
      while try <= attempts
        begin
          disk = execute( disk_get_req( name ) ) 
          @logger.debug("Waiting for #{name} disk deletion")
          sleep(SLEEPWAIT)
        rescue
          @logger.debug("#{name} disk deleted!")
          return
        end
        try += 1
      end
      @logger.debug("#{name} disk was not removed before timeout, may still exist")
    end

    def cleanup()
      attempts = @options[:timeout].to_i / SLEEPWAIT
      start = Time.now

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
      result = execute( instance_list_req() ) 
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
      result = execute( disk_list_req() ) 
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

    end

  end
end
