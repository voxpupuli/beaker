[ 'hypervisor' ].each do |lib|
  require "beaker/#{lib}"
end

module Beaker
  #Object that holds all the provisioned and non-provisioned virtual machines.
  #Controls provisioning, configuration, validation and cleanup of those virtual machines.
  class NetworkManager

    #Determine if a given host should be provisioned.
    #Provision if:
    # - only if we are running with ---provision
    # - only if we have a hypervisor
    # - only if either the specific hosts has no specification or has 'provision' in its config
    # - always if it is a vagrant box (vagrant boxes are always provisioned as they always need ssh key hacking)
    def provision? options, host
      command_line_says = options[:provision]
      host_says = host['hypervisor'] && (host.has_key?('provision') ? host['provision'] : true)
      (command_line_says && host_says) or (host['hypervisor'] =~/vagrant/)
    end

    def initialize(options, logger)
      @logger = logger
      @options = options
      @hosts = []
      @machines = {}
      @hypervisors = nil
    end

    #Provision all virtual machines.  Provision machines according to their set hypervisor, if no hypervisor
    #is selected assume that the described hosts are already up and reachable and do no provisioning.
    def provision
      if @hypervisors
        cleanup
      end
      @hypervisors = {}
      #sort hosts by their hypervisor, use hypervisor 'none' if no hypervisor is specified
      @options['HOSTS'].each_key do |name|
        host = @options['HOSTS'][name]
        hypervisor = host['hypervisor']
        hypervisor = provision?(@options, host) ? host['hypervisor'] : 'none'
        @logger.debug "Hypervisor for #{name} is #{hypervisor}"
        @machines[hypervisor] = [] unless @machines[hypervisor]
        @machines[hypervisor] << Beaker::Host.create(name, @options)
      end

      @machines.each_key do |type|
        @hypervisors[type] = Beaker::Hypervisor.create(type, @machines[type], @options)
        @hosts << @machines[type]
      end
      @hosts = @hosts.flatten
      @hosts
    end

    #Validate all provisioned machines, ensure that required packages are installed - if they are missing
    #attempt to add them.
    #@raise [Exception] Raise an exception if virtual machines fail to be validated
    def validate
      if @hypervisors
        @hypervisors.each_key do |type|
          @hypervisors[type].validate
        end
      end
    end

    #Configure all provisioned machines, adding any packages or settings required for SUTs
    #@raise [Exception] Raise an exception if virtual machines fail to be configured
    def configure
      if @hypervisors
        @hypervisors.each_key do |type|
          @hypervisors[type].configure
        end
      end
    end

    # configure proxy on all provioned machines
    #@raise [Exception] Raise an exception if virtual machines fail to be configured
    def proxy_package_manager
      if @hypervisors
        @hypervisors.each_key do |type|
          @hypervisors[type].proxy_package_manager
        end
      end
    end

    #Shut down network connections and revert all provisioned virtual machines
    def cleanup
      #shut down connections
      @hosts.each {|host| host.close }

      if @hypervisors
        @hypervisors.each_key do |type|
          @hypervisors[type].cleanup
        end
      end
      @hypervisors = nil
    end

  end
end
