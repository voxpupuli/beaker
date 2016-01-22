module Beaker
  #Beaker support for OpenStack
  #This code is EXPERIMENTAL!
  #Please file any issues/concerns at https://github.com/puppetlabs/beaker/issues
  class OpenStack < Beaker::Hypervisor

    SLEEPWAIT = 5

    #Create a new instance of the OpenStack hypervisor object
    #@param [<Host>] openstack_hosts The array of OpenStack hosts to provision
    #@param [Hash{Symbol=>String}] options The options hash containing configuration values
    #@option options [String] :openstack_api_key The key to access the OpenStack instance with (required)
    #@option options [String] :openstack_username The username to access the OpenStack instance with (required)
    #@option options [String] :openstack_auth_url The URL to access the OpenStack instance with (required)
    #@option options [String] :openstack_tenant The tenant to access the OpenStack instance with (required)
    #@option options [String] :openstack_region The region that each OpenStack instance should be provisioned on (optional)
    #@option options [String] :openstack_network The network that each OpenStack instance should be contacted through (required)
    #@option options [String] :openstack_keyname The name of an existing key pair that should be auto-loaded onto each
    #                                            OpenStack instance (optional)
    #@option options [String] :jenkins_build_url Added as metadata to each OpenStack instance
    #@option options [String] :department Added as metadata to each OpenStack instance
    #@option options [String] :project Added as metadata to each OpenStack instance
    #@option options [Integer] :timeout The amount of time to attempt execution before quiting and exiting with failure
    def initialize(openstack_hosts, options)
      require 'fog'
      @options = options
      @logger = options[:logger]
      @hosts = openstack_hosts
      @vms = []

      raise 'You must specify an Openstack API key (:openstack_api_key) for OpenStack instances!' unless @options[:openstack_api_key]
      raise 'You must specify an Openstack username (:openstack_username) for OpenStack instances!' unless @options[:openstack_username]
      raise 'You must specify an Openstack auth URL (:openstack_auth_url) for OpenStack instances!' unless @options[:openstack_auth_url]
      raise 'You must specify an Openstack tenant (:openstack_tenant) for OpenStack instances!' unless @options[:openstack_tenant]
      raise 'You must specify an Openstack network (:openstack_network) for OpenStack instances!' unless @options[:openstack_network]

      optionhash = {}
      optionhash[:provider]           = :openstack
      optionhash[:openstack_api_key]  = @options[:openstack_api_key]
      optionhash[:openstack_username] = @options[:openstack_username]
      optionhash[:openstack_auth_url] = @options[:openstack_auth_url]
      optionhash[:openstack_tenant]   = @options[:openstack_tenant]
      optionhash[:openstack_region]   = @options[:openstack_region] if @options[:openstack_region]

      @compute_client ||= Fog::Compute.new(optionhash)

      if not @compute_client
        raise "Unable to create OpenStack Compute instance (api key: #{@options[:openstack_api_key]}, username: #{@options[:openstack_username]}, auth_url: #{@options[:openstack_auth_url]}, tenant: #{@options[:openstack_tenant]})"
      end

      networkoptionhash = {}
      networkoptionhash[:provider]           = :openstack
      networkoptionhash[:openstack_api_key]  = @options[:openstack_api_key]
      networkoptionhash[:openstack_username] = @options[:openstack_username]
      networkoptionhash[:openstack_auth_url] = @options[:openstack_auth_url]
      networkoptionhash[:openstack_tenant]   = @options[:openstack_tenant]
      networkoptionhash[:openstack_region]   = @options[:openstack_region] if @options[:openstack_region]

      @network_client ||= Fog::Network.new(networkoptionhash)

      if not @network_client
        raise "Unable to create OpenStack Network instance (api_key: #{@options[:openstack_api_key]}, username: #{@options[:openstack_username]}, auth_url: #{@options[:openstack_auth_url]}, tenant: #{@options[:openstack_tenant]})"
      end

    end

    #Provided a flavor name return the OpenStack id for that flavor
    #@param [String] f The flavor name
    #@return [String] Openstack id for provided flavor name
    def flavor f
      @logger.debug "OpenStack: Looking up flavor '#{f}'"
      @compute_client.flavors.find { |x| x.name == f } || raise("Couldn't find flavor: #{f}")
    end

    #Provided an image name return the OpenStack id for that image
    #@param [String] i The image name
    #@return [String] Openstack id for provided image name
    def image i
      @logger.debug "OpenStack: Looking up image '#{i}'"
      @compute_client.images.find { |x| x.name == i } || raise("Couldn't find image: #{i}")
    end

    #Provided a network name return the OpenStack id for that network
    #@param [String] n The network name
    #@return [String] Openstack id for provided network name
    def network n
      @logger.debug "OpenStack: Looking up network '#{n}'"
      @network_client.networks.find { |x| x.name == n } || raise("Couldn't find network: #{n}")
    end

    # Create a volume client on request
    # @return [Fog::OpenStack::Volume] OpenStack volume client
    def volume_client_create
      options = {
        :provider           => :openstack,
        :openstack_api_key  => @options[:openstack_api_key],
        :openstack_username => @options[:openstack_username],
        :openstack_auth_url => @options[:openstack_auth_url],
        :openstack_tenant   => @options[:openstack_tenant],
        :openstack_region   => @options[:openstack_region],
      }
      @volume_client ||= Fog::Volume.new(options)
      unless @volume_client
        raise "Unable to create OpenStack Volume instance"\
              " (api_key: #{@options[:openstack_api_key]},"\
              " username: #{@options[:openstack_username]},"\
              " auth_url: #{@options[:openstack_auth_url]},"\
              " tenant: #{@options[:openstack_tenant]})"
      end
    end

    # Create and attach dynamic volumes
    #
    # Creates an array of volumes and attaches them to the current host.
    # The host bus type is determined by the image type, so by default
    # devices appear as /dev/vdb, /dev/vdc etc.  Setting the glance
    # properties hw_disk_bus=scsi, hw_scsi_model=virtio-scsi will present
    # them as /dev/sdb, /dev/sdc (or 2:0:0:1, 2:0:0:2 in SCSI addresses)
    #
    # @param host [Hash] thet current host defined in the nodeset
    # @param vm [Fog::Compute::OpenStack::Server] the server to attach to
    def provision_storage host, vm
      if host['volumes']
        # Lazily create the volume client if needed
        volume_client_create
        host['volumes'].keys.each_with_index do |volume, index|
          @logger.debug "Creating volume #{volume} for OpenStack host #{host.name}"

          # The node defintion file defines volume sizes in MB (due to precedent
          # with the vagrant virtualbox implementation) however OpenStack requires
          # this translating into GB
          openstack_size = host['volumes'][volume]['size'].to_i / 1000

          # Create the volume and wait for it to become available
          vol = @volume_client.volumes.create(
            :size         => openstack_size,
            :display_name => volume,
            :description  => "Beaker volume: host=#{host.name} volume=#{volume}",
          )
          vol.wait_for { ready? }

          # Fog needs a device name to attach as, so invent one.  The guest
          # doesn't pay any attention to this
          device = "/dev/vd#{('b'.ord + index).chr}"
          vm.attach_volume(vol.id, device)
        end
      end
    end

    # Detach and delete guest volumes
    # @param vm [Fog::Compute::OpenStack::Server] the server to detach from
    def cleanup_storage vm
      vm.volumes.each do |vol|
        @logger.debug "Deleting volume #{vol.name} for OpenStack host #{vm.name}"
        vm.detach_volume(vol.id)
        vol.wait_for { ready? }
        vol.destroy
      end
    end

    #Create new instances in OpenStack
    def provision
      @logger.notify "Provisioning OpenStack"

      @hosts.each do |host|
        host[:vmhostname] = generate_host_name
        @logger.debug "Provisioning #{host.name} (#{host[:vmhostname]})"
        options = {
          :flavor_ref => flavor(host[:flavor]).id,
          :image_ref  => image(host[:image]).id,
          :nics       => [ {'net_id' => network(@options[:openstack_network]).id } ],
          :name       => host[:vmhostname],
          :user_data  => host[:user_data] || "#cloud-config\nmanage_etc_hosts: true\n",
        }
        options[:key_name] = key_name(host)
        vm = @compute_client.servers.create(options)

        #wait for the new instance to start up
        start = Time.now
        try = 1
        attempts = @options[:timeout].to_i / SLEEPWAIT

        while try <= attempts
          begin
            vm.wait_for(5) { ready? }
            break
          rescue Fog::Errors::TimeoutError => e
            if try >= attempts
              @logger.debug "Failed to connect to new OpenStack instance #{host.name} (#{host[:vmhostname]})"
              raise e
            end
            @logger.debug "Timeout connecting to instance #{host.name} (#{host[:vmhostname]}), trying again..."
          end
          sleep SLEEPWAIT
          try += 1
        end

        # Associate a public IP to the server
        # Create if there are no floating ips available
        #
        # Do we already have an address?
        @logger.debug vm.addresses
        address=nil
        begin
          # Here we try and assign an address from a floating IP pool
          # This seems to fail on some implementations (FloatingIpPoolNotFound)
          ip = @compute_client.addresses.find { |ip| ip.instance_id.nil? }
          if ip.nil?
            @logger.debug "Creating IP for #{host.name} (#{host[:vmhostname]})"
            ip = @compute_client.addresses.create
          end
          ip.server = vm
          address = ip.ip

        rescue Fog::Compute::OpenStack::NotFound
          # Here, we fail to just trying to use an address that's already assigned if there is one
          # There may be better logic, but this worked in the original implementation
          # There might be an argument for checking whether an address is reachable a la
          # port_open? logic in host.rb but maybe race conditions

          begin
            if vm.addresses[@options[:openstack_network]]
              address = vm.addresses[@options[:openstack_network]].map{ |network| network['addr'] }.first
            end
          rescue NoMethodError
            @logger.debug "No current address retrievable from OpenStack data"
          end

        end

        raise 'Could not find or assign an address to the instance' unless address
        host[:ip] = address

        @logger.debug "OpenStack host #{host.name} (#{host[:vmhostname]}) assigned ip: #{host[:ip]}"

        #set metadata
        vm.metadata.update({:jenkins_build_url => @options[:jenkins_build_url].to_s,
                            :department        => @options[:department].to_s,
                            :project           => @options[:project].to_s })
        @vms << vm

        #enable root if user is not root
        enable_root(host)

        provision_storage(host, vm)
      end

      hack_etc_hosts @hosts, @options

    end

    #Destroy any OpenStack instances
    def cleanup
      @logger.notify "Cleaning up OpenStack"
      @vms.each do |vm|
        cleanup_storage(vm)
        @logger.debug "Release floating IPs for OpenStack host #{vm.name}"
        floating_ips = vm.all_addresses # fetch and release its floating IPs
        floating_ips.each do |address|
          @compute_client.disassociate_address(vm.id, address['ip'])
          @compute_client.release_address(address['id'])
        end
        @logger.debug "Destroying OpenStack host #{vm.name}"
        vm.destroy
        if @options[:openstack_keyname].nil?
          @logger.debug "Deleting random keypair"
          @compute_client.delete_key_pair vm.name
        end
      end
    end

    # Enables root access for a host when username is not root
    # This method ripped from the aws_sdk implementation and is probably wrong
    # because it iterates on a collection when there's no guarantee the collection
    # has all been brought up in openstack yet and will thus explode
    # @return [void]
    # @api private
    def enable_root_on_hosts
      @hosts.each do |host|
        enable_root(host)
      end
    end

    # enable root on a single host (the current one presumably) but only
    # if the username isn't 'root'
    def enable_root(host)
      if host['user'] != 'root'
        copy_ssh_to_root(host, @options)
        enable_root_login(host, @options)
        host['user'] = 'root'
        host.close
      end
    end

    #Get key_name from options or generate a new rsa key and add it to
    #OpenStack keypairs
    #
    #@param [Host] host The OpenStack host to provision
    #@return [String] key_name
    #@api private
    def key_name(host)
      if @options[:openstack_keyname]
        @logger.debug "Adding optional key_name #{@options[:openstack_keyname]} to #{host.name} (#{host[:vmhostname]})"
        @options[:openstack_keyname]
      else
        @logger.debug "Generate a new rsa key"
        key = OpenSSL::PKey::RSA.new 2048
        type = key.ssh_type
        data = [ key.to_blob ].pack('m0')
        @logger.debug "Creating Openstack keypair for public key '#{type} #{data}'"
        @compute_client.create_key_pair host[:vmhostname], "#{type} #{data}"
        host['ssh'][:key_data] = [ key.to_pem ]
        host[:vmhostname]
      end
    end
  end
end
