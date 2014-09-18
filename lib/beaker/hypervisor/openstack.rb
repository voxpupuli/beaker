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

      raise 'You must specify an Openstack API key (:oopenstack_api_key) for OpenStack instances!' unless @options[:openstack_api_key]
      raise 'You must specify an Openstack username (:openstack_username) for OpenStack instances!' unless @options[:openstack_username]
      raise 'You must specify an Openstack auth URL (:openstack_auth_url) for OpenStack instances!' unless @options[:openstack_auth_url]
      raise 'You must specify an Openstack tenant (:openstack_tenant) for OpenStack instances!' unless @options[:openstack_tenant]
      raise 'You must specify an Openstack network (:openstack_network) for OpenStack instances!' unless @options[:openstack_network]
      @compute_client ||= Fog::Compute.new(:provider => :openstack,
                                           :openstack_api_key => @options[:openstack_api_key],
                                           :openstack_username => @options[:openstack_username],
                                           :openstack_auth_url => @options[:openstack_auth_url],
                                           :openstack_tenant => @options[:openstack_tenant])
      if not @compute_client
        raise "Unable to create OpenStack Compute instance (api key: #{@options[:openstack_api_key]}, username: #{@options[:openstack_username]}, auth_url: #{@options[:openstack_auth_url]}, tenant: #{@options[:openstack_tenant]})"
      end
      @network_client || Fog::Network.new(
        :provider => :openstack,
        :openstack_api_key => @options[:openstack_api_key],
        :openstack_username => @options[:openstack_username],
        :openstack_auth_url => @options[:openstack_auth_url])
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

    #Create new instances in OpenStack
    def provision
      @logger.notify "Provisioning OpenStack"

      @hosts.each do |host|
        host[:vmhostname] = generate_host_name
        @logger.debug "Provisioning #{host.name} (#{host[:vmhostname]})"
        options = {
          :flavor_ref => flavor(host[:flavor]).id,
          :image_ref => image(host[:image]).id,
          :nics => [ {'net_id' => network(@options[:openstack_network]).id } ],
          :name => host[:vmhostname],
        }
        if @options[:openstack_keyname]
          @logger.debug "Adding optional key_name #{@options[:openstack_keyname]} to #{host.name} (#{host[:vmhostname]})"
          options[:key_name] = @options[:openstack_keyname]
        end
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
        ip = @compute_client.addresses.find { |ip| ip.instance_id.nil? }
        if ip.nil?
          @logger.debug "Creating IP for #{host.name} (#{host[:vmhostname]})"
          ip = @compute_client.addresses.create
        end
        ip.server = vm
        host[:ip] = ip.ip
        @logger.debug "OpenStack host #{host.name} (#{host[:vmhostname]}) assigned ip: #{host[:ip]}"

        #set metadata
        vm.metadata.update({:jenkins_build_url => @options[:jenkins_build_url].to_s,
                            :department        => @options[:department].to_s,
                            :project           => @options[:project].to_s })
        @vms << vm

      end
    end

    #Destroy any OpenStack instances
    def cleanup
      @logger.notify "Cleaning up OpenStack"
      @vms.each do |vm|
        @logger.debug "Release floating IPs for OpenStack host #{vm.name}"
        floating_ips = vm.all_addresses # fetch and release its floating IPs
        floating_ips.each do |address|
          @compute_client.disassociate_address(vm.id, address['ip'])
          @compute_client.release_address(address['id'])
        end
        @logger.debug "Destroying OpenStack host #{vm.name}"
        vm.destroy
      end
    end

  end
end
