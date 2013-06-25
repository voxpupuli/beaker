module PuppetAcceptance 
  class Vsphere < PuppetAcceptance::Hypervisor

    def initialize(vsphere_hosts, options, config)
      @options = options
      @@config = config['CONFIG'].dup
      @logger = options[:logger]
      @vsphere_hosts = vsphere_hosts
      require 'yaml' unless defined?(YAML)
      vsphere_credentials = VsphereHelper.load_config

      @logger.notify "Connecting to vSphere at #{vsphere_credentials[:server]}" +
        " with credentials for #{vsphere_credentials[:user]}"

      vsphere_helper = VsphereHelper.new( vsphere_credentials )

      vsphere_vms = {}
      @vsphere_hosts.each do |h|
        name = h["vmname"] || h.name
        real_snap = h["snapshot"] || @options[:snapshot]
        vsphere_vms[name] = real_snap
      end
      vms = vsphere_helper.find_vms(vsphere_vms.keys)
      vsphere_vms.each_pair do |name, snap|
        unless vm = vms[name]
          raise "Couldn't find VM #{name} in vSphere!"
        end

        snapshot = vsphere_helper.find_snapshot(vm, snap) or
          raise "Could not find snapshot '#{snap}' for VM #{vm.name}!"

        @logger.notify "Reverting #{vm.name} to snapshot '#{snap}'"
        start = Time.now
        # This will block for each snapshot...
        # The code to issue them all and then wait until they are all done sucks
        snapshot.RevertToSnapshot_Task.wait_for_completion

        time = Time.now - start
        @logger.notify "Spent %.2f seconds reverting" % time

        unless vm.runtime.powerState == "poweredOn"
          @logger.notify "Booting #{vm.name}"
          start = Time.now
          vm.PowerOnVM_Task.wait_for_completion
          @logger.notify "Spent %.2f seconds booting #{vm.name}" % (Time.now - start)
        end
      end

      vsphere_helper.close
    end

    def cleanup
      @logger.notify "Destroying vsphere boxes"
      vsphere_credentials = VsphereHelper.load_config

      @logger.notify "Connecting to vSphere at #{vsphere_credentials[:server]}" +
        " with credentials for #{vsphere_credentials[:user]}"

      vsphere_helper = VsphereHelper.new( vsphere_credentials )

      vm_names = @vsphere_hosts.map {|h| h['vmname'] || h.name }
      vms = vsphere_helper.find_vms vm_names
      vm_names.each do |name|
        unless vm = vms[name]
          raise "Couldn't find VM #{name} in vSphere!"
        end

        if vm.runtime.powerState == "poweredOn"
          @logger.notify "Shutting down #{vm.name}"
          start = Time.now
          vm.PowerOffVM_Task.wait_for_completion
          @logger.notify(
            "Spent %.2f seconds halting #{vm.name}" % (Time.now - start) )
        end
      end

      vsphere_helper.close
    end

  end
end
