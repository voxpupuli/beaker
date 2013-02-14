test_name "Remove acceptance VMs" do

  virtual_machines = {}
  hosts.each do |host|
    hypervisor = host['hypervisor'] || options[:vmrun]
    virtual_machines[hypervisor] ||= []
    virtual_machines[hypervisor] << host
  end

  if options[:preserve_hosts]
    hosts_config = {}
    hosts.each do |host|
      hosts_config[host.name] = {
        'roles' => host['roles'],
        'platform' => host['platform'],
        'ip' => host['ip'],
      }
    end

    exported_config = {
      'HOSTS' => hosts_config,
      'CONFIG' => config
    }

    FileUtils.mkdir_p('tmp')
    File.open("tmp/#{File.basename(options[:config])}", 'w') do |f|
      f.write(exported_config.to_yaml)
    end
  end

  if virtual_machines['blimpy'] and not options[:preserve_hosts]
    fleet = Blimpy.fleet do |fleet|
      virtual_machines['blimpy'].each do |host|
        fleet.add(:aws) do |ship|
          ship.name = host.name
        end
      end
    end

    fleet.destroy
  end

  if virtual_machines['vsphere'] and not options[:preserve_hosts]
    require File.expand_path(File.join(File.dirname(__FILE__),
                                       '..', '..','lib', 'puppet_acceptance',
                                       'utils', 'vsphere_helper'))


    vsphere_credentials = VsphereHelper.load_config

    logger.notify "Connecting to vsphere at #{vsphere_credentials[:server]}" +
      " with credentials for #{vsphere_credentials[:user]}"

    vsphere_helper = VsphereHelper.new( vsphere_credentials )

    vm_names = virtual_machines['vsphere'].map {|h| h['vmname'] || h.name }
    vms = vsphere_helper.find_vms vm_names
    vm_names.each do |name|
      unless vm = vms[name]
        fail_test("Couldn't find VM #{name} in vSphere!")
      end

      if vm.runtime.powerState == "poweredOn"
        logger.notify "Shutting down #{vm.name}"
        start = Time.now
        vm.PowerOffVM_Task.wait_for_completion
        logger.notify(
          "Spent %.2f seconds halting #{vm.name}" % (Time.now - start) )
      end
    end

    vsphere_helper.close

  end
end
