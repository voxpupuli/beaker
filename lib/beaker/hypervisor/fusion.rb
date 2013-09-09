module Beaker 
  class Fusion < Beaker::Hypervisor

  def initialize(fusion_hosts, options)
      require 'rubygems' unless defined?(Gem)
      begin
        require 'fission'
      rescue LoadError
        raise "Unable to load fission, please ensure it is installed!"
      end
      @logger = options[:logger]
      @options = options
      @fusion_hosts = fusion_hosts


      available = Fission::VM.all.data.collect{|vm| vm.name}.sort.join(", ")
      @logger.notify "Available VM names: #{available}"

      @fusion_hosts.each do |host|
        vm_name = host["vmname"] || host.name
        vm = Fission::VM.new vm_name
        raise "Could not find VM '#{vm_name}' for #{host.name}!" unless vm.exists?

        available_snapshots = vm.snapshots.data.sort.join(", ")
        @logger.notify "Available snapshots for #{host.name}: #{available_snapshots}"
        snap_name = host["snapshot"] 
        raise "No snapshot specified for #{host.name}" unless snap_name
        raise "Could not find snapshot '#{snap_name}' for host #{host.name}!" unless vm.snapshots.data.include? snap_name

        @logger.notify "Reverting #{host.name} to snapshot '#{snap_name}'"
        start = Time.now
        vm.revert_to_snapshot snap_name
        while vm.running?.data
          sleep 1
        end
        time = Time.now - start
        @logger.notify "Spent %.2f seconds reverting" % time

        @logger.notify "Resuming #{host.name}"
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
