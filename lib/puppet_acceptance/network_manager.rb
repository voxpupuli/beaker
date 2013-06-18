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
      @boxes = {}
      @virtual_machines.keys.each do |type|
        #provision all the boxes of this type
        @boxes[type] = PuppetAcceptance::Hypervisor.create(type, @virtual_machines[type], @options, @config)
        #now create a host object for each box in this provision set
        @boxes[type].names.each do |name|
          host = PuppetAcceptance::Host.create(name, @options, @config)
          #sometimes differently provisioned boxes use some custom host settings
          if @boxes[type].ssh_confs[name]
            host['ssh'] = @boxes[type].ssh_confs[name]
          end
          if @boxes[type].user
            host['user'] = @boxes[type].user
          end
          if @boxes[type].ips[name]
            host['ip'] = @boxes[type].ips[name]
          end
          #HACK HACK HACK - vagrant machines run as the vagrant user, this allows us to run commands with root permissions instead
          if type =~ /vagrant/
            host['command_wrapper'] = 'sudo su -c '
          end
          @hosts << host
        end
      end
      @noprovision_machines.each do |name|
        @hosts << PuppetAcceptance::Host.create(name, @options, @config)
      end
      @hosts
    end

    def cleanup
      #only cleanup if we aren't preserving hosts
      if not @options[:preserve_hosts]
        @boxes.each_key do |type|
          @boxes[type].cleanup
        end
      end
    end

  end
end
