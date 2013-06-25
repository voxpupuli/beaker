%w(hypervisor).each do |lib|
  begin
    require "puppet_acceptance/#{lib}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), lib))
  end
end

module PuppetAcceptance
  class NetworkManager
    HYPERVISOR_TYPES = ['solaris', 'blimpy', 'vsphere', 'fusion', 'aix', 'vcloud', 'vagrant']

    def initialize(config, options, logger)
      @logger = logger
      @options = options
      @hosts = []
      @config = config
      @virtual_machines = {}
      @noprovision_machines = []
      @config['HOSTS'].each_key do |name|
        host_info = @config['HOSTS'][name]
        #check to see if there are any specified hypervisors/snapshots
        hypervisor = host_info['hypervisor'] || @options[:hypervisor]
        #revert this box
        # - only if we are running with --revert
        # - only if we have a hypervisor
        # - only if either the specific hosts has no specification or has 'revert' in its config
        if @options[:revert] && hypervisor && (host_info.has_key?('revert') ? host_info['revert'] : true) #obey config file revert, defaults to reverting vms
          raise "Invalid hypervisor: #{hypervisor} (#{name})" unless HYPERVISOR_TYPES.include? hypervisor
          @logger.debug "Hypervisor for #{name} is #{host_info['hypervisor'] || 'default' }, and I'm going to use #{hypervisor}"
          @virtual_machines[hypervisor] = [] unless @virtual_machines[hypervisor]
          @virtual_machines[hypervisor] << name
        else #this is a non-provisioned machine, deal with it without hypervisors
          @noprovision_machines << name
        end

      end
    end

    def provision
      @provisioned_set = {}
      @virtual_machines.each do |type, names|
        hosts_for_type = []
        #set up host objects for provisioned provisioned_set
        names.each do |name|
          host = PuppetAcceptance::Host.create(name, @options, @config)
          if type =~ /vagrant/
            host['command_wrapper'] = 'sudo su -c '
          end
          hosts_for_type << host
        end
        @provisioned_set[type] = PuppetAcceptance::Hypervisor.create(type, hosts_for_type, @options, @config)
        @hosts << hosts_for_type
      end
      @noprovision_machines.each do |name|
        @hosts << PuppetAcceptance::Host.create(name, @options, @config)
      end
      @hosts = @hosts.flatten
      @hosts
    end

    def cleanup
      #only cleanup if we aren't preserving hosts
      #shut down connections
      @hosts.each {|host| host.close }

      if not @options[:preserve_hosts]
        @provisioned_set.each_key do |type|
          @provisioned_set[type].cleanup
        end
      end
    end

  end
end
