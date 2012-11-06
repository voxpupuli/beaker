test_name "Remove acceptance VMs"

  if options[:vmrun] == 'blimpy' and not options[:preserve_hosts]
    fleet = Blimpy.fleet do |fleet|
      hosts.each do |host|
        fleet.add(:aws) do |ship|
          ship.name = host.name
        end
      end
    end

    fleet.destroy

  elsif options[:vmrun] == 'vsphere' and not options[:preserve_hosts]
    require File.expand_path(File.join(File.dirname(__FILE__),
                                       '..', '..','lib', 'puppet_acceptance',
                                       'utils', 'vsphere_helper'))


    vsphere_credentials = VsphereHelper.load_config

    # Do more than manage two different config files...
    logger.notify "Connecting to vsphere at #{vsphere_credentials[:server]}" +
      " with credentials for #{vsphere_credentials[:user]}"

    vsphere_helper = VsphereHelper.new vsphere_credentials

    vm_names = hosts.map {|h| h.name }
    vms = vsphere_helper.find_vms vm_names
    vm_names.each do |name|
      unless vm = vms[name]
        fail_test("Couldn't find VM #{name} in vSphere!")
      end

      if vm.runtime.powerState == "poweredOn"
        logger.notify "Shutting down #{vm.name}"
        start = Time.now
        vm.PowerOffVM_Task.wait_for_completion
        logger.notify "Spent %.2f seconds halting #{vm.name}" % (Time.now - start)
      end
    end

    vsphere_helper.close

  else
    skip_test "Skipping cleanup VM step"
  end

