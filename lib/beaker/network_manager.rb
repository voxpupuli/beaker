%w(hypervisor).each do |lib|
  begin
    require "beaker/#{lib}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), lib))
  end
end

module Beaker
  class NetworkManager
    HYPERVISOR_TYPES = ['solaris', 'blimpy', 'vsphere', 'fusion', 'aix', 'vcloud', 'vagrant']

    def initialize(options, logger)
      @logger = logger
      @options = options
      @hosts = []
      @virtual_machines = {}
      @noprovision_machines = []
    end

    def provision
      #sort hosts into those to be provisioned and those to use non-provisioned
      @options['HOSTS'].each_key do |name|
        host_info = @options['HOSTS'][name]
        #check to see if this host has a hypervisor 
        hypervisor = host_info['hypervisor'] 
        #provision this box
        # - only if we are running with --provision
        # - only if we have a hypervisor
        # - only if either the specific hosts has no specification or has 'provision' in its config
        if @options[:provision] && hypervisor && (host_info.has_key?('provision') ? host_info['provision'] : true) #obey config file provision, defaults to provisioning vms
          raise "Invalid hypervisor: #{hypervisor} (#{name})" unless HYPERVISOR_TYPES.include? hypervisor
          @logger.debug "Hypervisor for #{name} is #{host_info['hypervisor'] || 'default' }, and I'm going to use #{hypervisor}"
          @virtual_machines[hypervisor] = [] unless @virtual_machines[hypervisor]
          @virtual_machines[hypervisor] << name
        else #this is a non-provisioned machine, deal with it without hypervisors
          @logger.debug "No hypervisor for #{name}, connecting to host without provisioning"
          @noprovision_machines << name
        end
      end

      @provisioned_set = {}
      @virtual_machines.each do |type, names|
        hosts_for_type = []
        #set up host objects for provisioned provisioned_set
        names.each do |name|
          host = Beaker::Host.create(name, @options)
          hosts_for_type << host
        end
        @provisioned_set[type] = Beaker::Hypervisor.create(type, hosts_for_type, @options)
        @hosts << hosts_for_type
      end
      @noprovision_machines.each do |name|
        @hosts << Beaker::Host.create(name, @options)
      end
      @hosts = @hosts.flatten
      @hosts
    end

    def cleanup
      #only cleanup if we aren't preserving hosts
      #shut down connections
      @hosts.each {|host| host.close }

      if not @options[:preserve_hosts]
        if @provisioned_set
          @provisioned_set.each_key do |type|
            if @provisioned_set[type]
              @provisioned_set[type].cleanup
            end
          end
        end
      end
    end

  end
end
