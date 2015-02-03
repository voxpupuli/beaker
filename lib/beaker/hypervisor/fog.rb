require 'fog'

module Beaker
  #Beaker support for Fog
  class Fog < Beaker::Hypervisor

    SLEEPWAIT = 5

    #Create a new instance of the Fog hypervisor object
    #@param [<Host>] hosts The array of Fog hosts to provision
    #@param [Hash{Symbol=>String}] options The options hash containing configuration values
    def initialize(hosts, options)
      @options = options
      @logger = options[:logger]
      @hosts = hosts
      @vms = []

      host = hosts.first

      fog_auth = get_cloud_auth_method(hosts)

      fog_compute_options = { :provider => host[:cloud_provider]}.merge( fog_auth )

      @compute_client ||= ::Fog::Compute.new( fog_compute_options )

      if not @compute_client
        raise "Unable to create #{host[:cloud_provider]} Compute instance"
      end
    end

    # Provision all hosts in cloud using the Fog API
    #
    # @return [void]
    def provision
      @hosts.each do |host|
        @logger.notify "Provisioning #{host[:cloud_provider]} using Fog"
        host[:vmhostname] = "beaker-#{generate_host_name}"
        @logger.debug "Provisioning #{host.name} (#{host[:vmhostname]})"

        extras = provider_specific_fields(host)

        default_server_options = {
          :name => host[:vmhostname],
          :image_id => host[:image_id],
          :public_key_path => host[:public_key_path] || @options[:fog_private_key],
          :private_key_path => host[:private_key_path] || @options[:fog_public_key],
        }

        server_options = default_server_options.merge(extras)

        vm = @compute_client.servers.bootstrap(server_options)

        @logger.debug "Waiting for #{host.name} (#{host[:vmhostname]}) to respond"
        vm.wait_for {
          ready?
        }

        host[:ip] = vm.public_ip_address

        @vms << vm

      end
    end

    # Cleanup all earlier provisioned machines on cloud of choice using Fog
    #
    # #cleanup does nothing without a #provision call first.
    #
    # @return [void]
    def cleanup
      @logger.notify "Cleaning up Fog Created Servers"
      @vms.each do |vm|
        @logger.debug "Destroying host: #{vm.name}"
        vm.destroy
      end
    end

    # Return a hash containing the auth credentials for the VPS of choice
    #
    # Every provider has different auth methods, so we have to specify the keys
    #
    # @param [Array<Beaker::Host>] hosts Array of Beaker::Host objects
    # @return [Hash<Symbol, String>] fog_auth Auth keys for given provider
    # @api private
    def get_cloud_auth_method(hosts)
      host = hosts.first

      provider = host[:cloud_provider]

      case provider
      when /DigitalOcean/
        fog_auth = {
          :digitalocean_api_key => host[:digitalocean_api_key],
          :digitalocean_client_id => host[:digitalocean_client_id],
        }
      else
        raise NotImplementedError, "Don't know the cloud auth for #{provider}"
      end
    end

    # Return a hash containing the provider specific fields for the VPS of choice
    #
    # Not everyone has region ids, some you have to specify networks and such
    #
    # @param [Array<Beaker::Host>] hosts Array of Beaker::Host objects
    # @return [Hash<Symbol, String>] specific_fields Provider specific fields
    # @api private
    def provider_specific_fields(host)
      provider = host[:cloud_provider]

      case provider
      when /DigitalOcean/
        specific_fields = {
          :flavor_id => host[:flavor_id],
          :region_id => host[:region_id],
          :size_id   => host[:size_id],
        }
      else
        raise NotImplementedError, "Cant find the server specific fields for #{provider}"
      end

    end

  end
end
