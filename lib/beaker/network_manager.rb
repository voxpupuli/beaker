%w(hypervisor).each do |lib|
  begin
    require "beaker/#{lib}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), lib))
  end
end

module Beaker
  class NetworkManager
    HYPERVISOR_TYPES = ['solaris', 'blimpy', 'vsphere', 'fusion', 'aix', 'vcloud', 'vagrant', 'docker']

    def provision? options, host 
      #provision this box
      # - only if we are running with --provision
      # - only if we have a hypervisor
      # - only if either the specific hosts has no specification or has 'provision' in its config
      # - always if it is a vagrant box (vagrant boxes are always provisioned as they always need ssh key hacking)
      command_line_says = options[:provision] 
      host_says = host['hypervisor'] && (host.has_key?('provision') ? host['provision'] : true) 
      (command_line_says && host_says) or (host['hypervisor'] =~/vagrant/)
    end

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
        host = @options['HOSTS'][name]
        hypervisor = host['hypervisor']
        if provision?(@options, host)
          raise "Invalid hypervisor: #{hypervisor} (#{name})" unless HYPERVISOR_TYPES.include? hypervisor
          @logger.debug "Hypervisor for #{name} is #{hypervisor}"
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
      #shut down connections
      @hosts.each {|host| host.close }

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
