require 'google/api_client'
require 'json'
require 'time'
require 'ostruct'

module Beaker
  #Beaker helper module for doing API level Google Compute Engine interaction.
  class GoogleComputeHelper

    class GoogleComputeError < StandardError
    end

    SLEEPWAIT = 5

    AUTH_URL = 'https://www.googleapis.com/auth/compute'
    API_VERSION = 'v1'
    BASE_URL = "https://www.googleapis.com/compute/#{API_VERSION}/projects/"
    CENTOS_PROJECT = 'centos-cloud'
    DEBIAN_PROJECT = 'debian-cloud'
    DEFAULT_ZONE_NAME = 'us-central1-a'
    DEFAULT_MACHINE_TYPE = 'n1-highmem-2'
    DEFAULT_DISK_SIZE = 25

    #Create a new instance of the Google Compute Engine helper object
    #@param [Hash{Symbol=>String}] options The options hash containing configuration values
    #@option options [String] :gce_project The Google Compute Project name to connect to
    #@option options [String] :gce_keyfile The location of the Google Compute service account keyfile
    #@option options [String] :gce_password The password for the Google Compute service account key
    #@option options [String] :gce_email The email address for the Google Compute service account
    #@option options [String] :gce_machine_type A Google Compute machine type used to create instances, defaults to n1-highmem-2
    #@option options [Integer] :timeout The amount of time to attempt execution before quiting and exiting with failure
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

    #Determines the default Google Compute zone based upon options and defaults
    #@return The full URL to the default zone in which Google Compute requests will be sent
    def default_zone
      BASE_URL + @options[:gce_project] + '/global/zones/' + DEFAULT_ZONE_NAME
    end

    #Determines the default Google Compute network based upon defaults and options
    #@return The full URL to the default network in which Google Compute instances will operate
    def default_network
      BASE_URL + @options[:gce_project] + '/global/networks/default'
    end

    #Determines the Google Compute project which contains bases instances of type name
    #@param [String] name The platform type to search for
    #@return The Google Compute project name
    #@raise [Exception] If the provided platform type name is unsupported
    def get_platform_project(name)
      if name =~ /debian/
        return DEBIAN_PROJECT
      elsif name =~ /centos/
        return CENTOS_PROJECT
      else
        raise "Unsupported platform for Google Compute Engine: #{name}"
      end
    end

    #Create the Google APIClient object which will be used for accessing the Google Compute API
    #@param version The version number of Beaker currently running
    def set_client(version)
      @client = Google::APIClient.new({:application_name => "Beaker", :application_version => version})
    end

    #Discover the currently active Google Compute API
    #@param [String] version The version of the Google Compute API to discover
    #@param [Integer] start The time when we started code execution, it is compared to Time.now to determine how many
    #                       further code execution attempts remain
    #@param [Integer] attempts The total amount of attempts to execute that we are willing to allow
    #@raise [Exception] Raised if we fail to discover the Google Compute API, either through errors or running out of attempts
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

    #Creates an authenticated connection to the Google Compute Engine API
    #@param [String] keyfile The location of the Google Compute Service Account keyfile to use for authentication
    #@param [String] password The password for the provided Google Compute Service Account key
    #@param [String] email The email address of the Google Compute Service Account we are using to connect
    #@param [Integer] start The time when we started code execution, it is compared to Time.now to determine how many
    #                       further code execution attempts remain
    #@param [Integer] attempts The total amount of attempts to execute that we are willing to allow
    #@raise [Exception] Raised if we fail to create an authenticated connection to the Google Compute API, either through errors or running out of attempts
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

    #Executes a provided Google Compute request using a previously configured and authenticated Google Compute client connection
    #@param [Hash] req A correctly formatted Google Compute request object
    #@param [Integer] start The time when we started code execution, it is compared to Time.now to determine how many
    #                       further code execution attempts remain
    #@param [Integer] attempts The total amount of attempts to execute that we are willing to allow
    #@raise [Exception] Raised if we fail to execute the request, either through errors or running out of attempts
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

    #Determines the latest image available for the provided platform name.  We currently only support debian-7 and centos-6 platforms.
    #@param [String] platform The platform type to search for an instance of, must be one of /debian-7-.*/ or /centos-6-.*/
    #@param [Integer] start The time when we started code execution, it is compared to Time.now to determine how many
    #                       further code execution attempts remain
    #@param [Integer] attempts The total amount of attempts to execute that we are willing to allow
    #@return [Hash] The image hash of the latest, non-deprecated image for the provided platform
    #@raise [Exception] Raised if we fail to execute the request, either through errors or running out of attempts
    def get_latest_image(platform, start, attempts)
      #use the platform version numbers instead of codenames
      platform = platform.with_version_number
      #break up my platform for information
      platform_name, platform_version, platform_extra_info = platform.split('-', 3)
      #find latest image to use
      result = execute( image_list_req(get_platform_project(platform_name)), start, attempts )
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

    #Determines the Google Compute machineType object based upon the selected gce_machine_type option
    #@param [Integer] start The time when we started code execution, it is compared to Time.now to determine how many
    #                       further code execution attempts remain
    #@param [Integer] attempts The total amount of attempts to execute that we are willing to allow
    #@return [Hash] The machineType hash
    #@raise [Exception] Raised if we fail get the machineType, either through errors or running out of attempts
    def get_machineType(start, attempts)
      execute( machineType_get_req, start, attempts )
    end

    #Determines the Google Compute network object in use for the current connection
    #@param [Integer] start The time when we started code execution, it is compared to Time.now to determine how many
    #                       further code execution attempts remain
    #@param [Integer] attempts The total amount of attempts to execute that we are willing to allow
    #@return [Hash] The network hash
    #@raise [Exception] Raised if we fail get the network, either through errors or running out of attempts
    def get_network(start, attempts)
      execute( network_get_req, start, attempts)
    end

    #Determines a list of existing Google Compute instances
    #@param [Integer] start The time when we started code execution, it is compared to Time.now to determine how many
    #                       further code execution attempts remain
    #@param [Integer] attempts The total amount of attempts to execute that we are willing to allow
    #@return [Array[Hash]] The instances array of hashes
    #@raise [Exception] Raised if we fail determine the list of existing instances, either through errors or running out of attempts
    def list_instances(start, attempts)
      instances = execute( instance_list_req(), start, attempts )
      instances["items"]
    end

    #Determines a list of existing Google Compute disks
    #@param [Integer] start The time when we started code execution, it is compared to Time.now to determine how many
    #                       further code execution attempts remain
    #@param [Integer] attempts The total amount of attempts to execute that we are willing to allow
    #@return [Array[Hash]] The disks array of hashes
    #@raise [Exception] Raised if we fail determine the list of existing disks, either through errors or running out of attempts
    def list_disks(start, attempts)
      disks = execute( disk_list_req(), start, attempts )
      disks["items"]
    end

    #Determines a list of existing Google Compute firewalls
    #@param [Integer] start The time when we started code execution, it is compared to Time.now to determine how many
    #                       further code execution attempts remain
    #@param [Integer] attempts The total amount of attempts to execute that we are willing to allow
    #@return [Array[Hash]] The firewalls array of hashes
    #@raise [Exception] Raised if we fail determine the list of existing firewalls, either through errors or running out of attempts
    def list_firewalls(start, attempts)
      result = execute( firewall_list_req(), start, attempts )
      firewalls = result["items"]
      firewalls.delete_if{|f| f['name'] =~ /default-allow-internal|default-ssh/}
      firewalls
    end

    #Create a Google Compute firewall on the current connection
    #@param [String] name The name of the firewall to create
    #@param [Hash] network The Google Compute network hash in which to create the firewall
    #@param [Integer] start The time when we started code execution, it is compared to Time.now to determine how many
    #                       further code execution attempts remain
    #@param [Integer] attempts The total amount of attempts to execute that we are willing to allow
    #@raise [Exception] Raised if we fail create the firewall, either through errors or running out of attempts
    def create_firewall(name, network, start, attempts)
      execute( firewall_insert_req( name, network['selfLink'] ), start, attempts )
    end

    #Create a Google Compute disk on the current connection
    #@param [String] name The name of the disk to create
    #@param [Hash] img The Google Compute image to use for instance creation
    #@param [Integer] start The time when we started code execution, it is compared to Time.now to determine how many
    #                       further code execution attempts remain
    #@param [Integer] attempts The total amount of attempts to execute that we are willing to allow
    #@raise [Exception] Raised if we fail create the disk, either through errors or running out of attempts
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

    #Create a Google Compute instance on the current connection
    #@param [String] name The name of the instance to create
    #@param [Hash] img The Google Compute image to use for instance creation
    #@param [Hash] machineType The Google Compute machineType
    #@param [Hash] disk The Google Compute disk to attach to the newly created instance
    #@param [Integer] start The time when we started code execution, it is compared to Time.now to determine how many
    #                       further code execution attempts remain
    #@param [Integer] attempts The total amount of attempts to execute that we are willing to allow
    #@raise [Exception] Raised if we fail create the instance, either through errors or running out of attempts
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

    #Add key/value pairs to a  Google Compute instance on the current connection
    #@param [String] name The name of the instance to add metadata to
    #@param [String] fingerprint A hash of the metadata's contents of the given instance
    #@param [Array<Hash>] data An array of hashes.  Each hash should have a key and a value.
    #@param [Integer] start The time when we started code execution, it is compared to Time.now to determine how many
    #                       further code execution attempts remain
    #@param [Integer] attempts The total amount of attempts to execute that we are willing to allow
    #@raise [Exception] Raised if we fail to add metadata, either through errors or running out of attempts
    def setMetadata_on_instance(name, fingerprint, data, start, attempts)
      zone_operation = execute( instance_setMetadata_req( name, fingerprint, data), start, attempts )
      status = ''
      try = (Time.now - start) / SLEEPWAIT
      while status !~ /DONE/ and try <= attempts
        begin
          operation = execute( operation_get_req( zone_operation['name'] ), start, attempts )
          status = operation['status']
        rescue GoogleComputeError => e
          @logger.debug("Waiting for tags to be added to #{name}")
          sleep(SLEEPWAIT)
        end
        try += 1
      end
      if status == ''
        raise "Unable to set metaData (#{tags.to_s}) on #{name}"
      end
      zone_operation
    end

    #Delete a Google Compute instance on the current connection
    #@param [String] name The name of the instance to delete
    #@param [Integer] start The time when we started code execution, it is compared to Time.now to determine how many
    #                       further code execution attempts remain
    #@param [Integer] attempts The total amount of attempts to execute that we are willing to allow
    #@raise [Exception] Raised if we fail delete the instance, either through errors or running out of attempts
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

    #Delete a Google Compute disk on the current connection
    #@param [String] name The name of the disk to delete
    #@param [Integer] start The time when we started code execution, it is compared to Time.now to determine how many
    #                       further code execution attempts remain
    #@param [Integer] attempts The total amount of attempts to execute that we are willing to allow
    #@raise [Exception] Raised if we fail delete the disk, either through errors or running out of attempts
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

    #Delete a Google Compute firewall on the current connection
    #@param [String] name The name of the firewall to delete
    #@param [Integer] start The time when we started code execution, it is compared to Time.now to determine how many
    #                       further code execution attempts remain
    #@param [Integer] attempts The total amount of attempts to execute that we are willing to allow
    #@raise [Exception] Raised if we fail delete the firewall, either through errors or running out of attempts
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


    #Create a Google Compute list all images request
    #@param [String] name The Google Compute project name to query
    #@return [Hash] A correctly formatted Google Compute request hash
    def image_list_req(name)
      { :api_method  => @compute.images.list,
        :parameters  => { 'project' => name } }
    end

    #Create a Google Compute list all disks request
    #@return [Hash] A correctly formatted Google Compute request hash
    def disk_list_req
      { :api_method  => @compute.disks.list,
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME } }
    end

    #Create a Google Compute get disk request
    #@param [String] name The name of the disk to query for
    #@return [Hash] A correctly formatted Google Compute request hash
    def disk_get_req(name)
      { :api_method  => @compute.disks.get,
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME, 'disk' => name } }
    end

    #Create a Google Compute disk delete request
    #@param [String] name The name of the disk delete
    #@return [Hash] A correctly formatted Google Compute request hash
    def disk_delete_req(name)
      { :api_method  => @compute.disks.delete,
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME, 'disk' => name } }
    end

    #Create a Google Compute disk create request
    #@param [String] name The name of the disk to create
    #@param [String] source The link to a Google Compute image to base the disk creation on
    #@return [Hash] A correctly formatted Google Compute request hash
    def disk_insert_req(name, source)
      { :api_method  => @compute.disks.insert,
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME, 'sourceImage' => source },
        :body_object => { 'name' => name, 'sizeGb' => DEFAULT_DISK_SIZE } }
    end

    #Create a Google Compute get firewall request
    #@param [String] name The name of the firewall to query fo
    #@return [Hash] A correctly formatted Google Compute request hash
    def firewall_get_req(name)
      { :api_method  => @compute.firewalls.get,
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME, 'firewall' => name } }
    end

    #Create a Google Compute insert firewall request, open ports 443, 8140 and 61613
    #@param [String] name The name of the firewall to create
    #@param [String] network The link to the Google Compute network to attach this firewall to
    #@return [Hash] A correctly formatted Google Compute request hash
    def firewall_insert_req(name, network)
      { :api_method  => @compute.firewalls.insert,
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME },
        :body_object => { 'name' => name,
                          'allowed'=> [ { 'IPProtocol' => 'tcp', "ports" =>  [ '443', '8140', '61613', '8080', '8081' ]} ],
                          'network'=> network,
                          'sourceRanges' => [ "0.0.0.0/0" ] } }
    end

    #Create a Google Compute delete firewall request
    #@param [String] name The name of the firewall to delete
    #@return [Hash] A correctly formatted Google Compute request hash
    def firewall_delete_req(name)
      { :api_method  => @compute.firewalls.delete,
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME, 'firewall' => name } }
    end

    #Create a Google Compute list firewall request
    #@return [Hash] A correctly formatted Google Compute request hash
    def firewall_list_req()
      { :api_method  => @compute.firewalls.list,
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME } }
    end

    #Create a Google Compute get network request
    #@param [String] name (default) The name of the network to access information about
    #@return [Hash] A correctly formatted Google Compute request hash
    def network_get_req(name = 'default')
      { :api_method  => @compute.networks.get,
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME, 'network' => name } }
    end

    #Create a Google Compute zone operation request
    #@return [Hash] A correctly formatted Google Compute request hash
    def operation_get_req(name)
      { :api_method  => @compute.zone_operations.get,
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME, 'operation' => name } }
    end

    #Set tags on a Google Compute instance
    #@param [Array<String>] data An array of tags to be added to an instance
    #@return [Hash] A correctly formatted Google Compute request hash
    def instance_setMetadata_req(name, fingerprint, data)
      { :api_method => @compute.instances.set_metadata,
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME, 'instance' => name },
        :body_object => { 'kind' => 'compute#metadata',
                          'fingerprint'  => fingerprint,
                          'items' => data }
      }
    end

    #Create a Google Compute list instance request
    #@return [Hash] A correctly formatted Google Compute request hash
    def instance_list_req
      { :api_method  => @compute.instances.list,
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME } }
    end

    #Create a Google Compute get instance request
    #@param [String] name The name of the instance to query for
    #@return [Hash] A correctly formatted Google Compute request hash
    def instance_get_req(name)
      { :api_method  => @compute.instances.get,
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME, 'instance' => name } }
    end

    #Create a Google Compute instance delete request
    #@param [String] name The name of the instance to delete
    #@return [Hash] A correctly formatted Google Compute request hash
    def instance_delete_req(name)
      { :api_method  => @compute.instances.delete,
        :parameters  => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME, 'instance' => name } }
    end

    #Create a Google Compute instance create request
    #@param [String] name The name of the instance to create
    #@param [String] image The link to the image to use for instance create
    #@param [String] machineType The link to the type of Google Compute instance to create (indicates cpus and memory size)
    #@param [String] disk The link to the disk to be used by the newly created instance
    #@return [Hash] A correctly formatted Google Compute request hash
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

    #Create a Google Compute machineType get request
    #@return [Hash] A correctly formatted Google Compute request hash
    def machineType_get_req()
      { :api_method => @compute.machine_types.get,
        :parameters => { 'project' => @options[:gce_project], 'zone' => DEFAULT_ZONE_NAME, 'machineType' => @options[:gce_machine_type] || DEFAULT_MACHINE_TYPE } }
    end

  end
end
