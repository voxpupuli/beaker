require 'yaml' unless defined?(YAML)

module Beaker
  class Vsphere < Beaker::Hypervisor

    def initialize(vsphere_hosts, options)
      @options = options
      @logger = options[:logger]
      @hosts = vsphere_hosts
    end

    def provision
      vsphere_credentials = VsphereHelper.load_config(@options[:dot_fog])

      @logger.notify "Connecting to vSphere at #{vsphere_credentials[:server]}" +
        " with credentials for #{vsphere_credentials[:user]}"

      vsphere_helper = VsphereHelper.new( vsphere_credentials )

      vsphere_vms = {}
      @hosts.each do |h|
        name = h["vmname"] || h.name
        vsphere_vms[name] = h["snapshot"]
      end
      vms = vsphere_helper.find_vms(vsphere_vms.keys)
      vsphere_vms.each_pair do |name, snap|
        unless vm = vms[name]
          raise "Couldn't find VM #{name} in vSphere!"
        end

        if snap
          snapshot = vsphere_helper.find_snapshot(vm, snap) or
            raise "Could not find snapshot '#{snap}' for VM #{vm.name}!"

          @logger.notify "Reverting #{vm.name} to snapshot '#{snap}'"
          start = Time.now
          # This will block for each snapshot...
          # The code to issue them all and then wait until they are all done sucks
          snapshot.RevertToSnapshot_Task.wait_for_completion

          time = Time.now - start
          @logger.notify "Spent %.2f seconds reverting" % time
        end

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
      vsphere_credentials = VsphereHelper.load_config(@options[:dot_fog])

      @logger.notify "Connecting to vSphere at #{vsphere_credentials[:server]}" +
        " with credentials for #{vsphere_credentials[:user]}"

      vsphere_helper = VsphereHelper.new( vsphere_credentials )

      vm_names = @hosts.map {|h| h['vmname'] || h.name }
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
