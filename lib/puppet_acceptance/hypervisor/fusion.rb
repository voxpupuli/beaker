module PuppetAcceptance 
  class Fusion < PuppetAcceptance::Hypervisor

  def initialize(hosts_to_provision, options, config)
      require 'rubygems' unless defined?(Gem)
      begin
        require 'fission'
      rescue LoadError
        raise "Unable to load fission, please ensure it is installed!"
      end
      set_defaults(hosts_to_provision)

      @logger = options[:logger]
      @options = options
      @config = config

      available = Fission::VM.all.data.collect{|vm| vm.name}.sort.join(", ")
      @logger.notify "Available VM names: #{available}"

      hosts_to_provision.each do |name|
        host_info = @config['HOSTS'][name]
        fission_opts = host_info["fission"] || {}
        vm_name = host_info["vmname"] || name
        vm = Fission::VM.new vm_name
        raise "Could not find VM '#{vm_name}' for #{name}!" unless vm.exists?

        available_snapshots = vm.snapshots.data.sort.join(", ")
        @logger.notify "Available snapshots for #{name}: #{available_snapshots}"
        snap_name = host_info["snapshot"] || fission_opts["snapshot"] || @options[:snapshot]
        raise "No snapshot specified for #{name}" unless snap_name
        raise "Could not find snapshot '#{snap_name}' for host #{name}!" unless vm.snapshots.data.include? snap_name

        @logger.notify "Reverting #{name} to snapshot '#{snap_name}'"
        start = Time.now
        vm.revert_to_snapshot snap_name
        while vm.running?.data
          sleep 1
        end
        time = Time.now - start
        @logger.notify "Spent %.2f seconds reverting" % time

        @logger.notify "Resuming #{name}"
        start = Time.now
        vm.start :headless => true
        until vm.running?.data
          sleep 1
        end
        time = Time.now - start
        @logger.notify "Spent %.2f seconds resuming VM" % time
      end
    end #revert_fusion

    def cleanup
      @logger.notify "No cleanup for fusion boxes"
    end

end
end
