
module SnapshotFinder
  def self.find_snapshot vm, snapname
    search_child_snaps vm.snapshot.rootSnapshotList, snapname
  end

  def self.search_child_snaps tree, snapname
    snapshot = nil
    tree.each do |child|
      if child.name == snapname
        snapshot ||= child.snapshot
      else
        snapshot ||= search_child_snaps child.childSnapshotList, snapname
      end
    end
    snapshot
  end
end

test_name "Revert VMs"

  snap = options[:snapshot] || options[:type]
  snap = 'git' if options[:type] == 'gem'  # Sweet, sweet consistency

  if options[:vmrun] == 'vsphere'
    require 'yaml' unless defined?(YAML)
    require 'rubygems' unless defined?(Gem)
    begin
      require 'rbvmomi'
    rescue LoadError
      fail_test "Unable to load RbVmomi, please ensure its installed"
    end

    vInfo = YAML.load_file '/etc/plharness/vsphere'
    fail_test "Cant load vSphere config" unless vInfo

    logger.notify "Connecting to vsphere at #{vInfo['location']}" +
      " with credentials for #{vInfo['user']}"

    vsphere = RbVmomi::VIM.connect :host     => vInfo['location'],
                                   :user     => vInfo['user'],
                                   :password => vInfo['pass'],
                                   :insecure => true
    fail_test('Could not connect to vSphere') unless vsphere

    dc = vsphere.serviceInstance.find_datacenter(vInfo['dc']) or
      fail_test "Could not connect to Datacenter #{vInfo['dc']}"

    hosts.each do |host|
      vm = dc.find_vm(host.name) or
        fail_test "Could not find host #{host}"

      snapshot = SnapshotFinder.find_snapshot(vm, snap) or
        fail_test("Could not find snapshot #{snap} for host #{host}")

      logger.notify "Reverting #{host} to snapshot #{snap}"
      start = Time.now
      # This will block for each snapshot...
      # The code to issue them all and then wait until they are all done sucks
      snapshot.RevertToSnapshot_Task.wait_for_completion

      time = Time.now - start
      logger.notify "Spent %f.2 seconds reverting" % time
    end

  elsif options[:vmrun]

    vmserver = options[:vmrun]
    hosts.each do |host|
      logger.warn ""
      logger.warn "Warning you are using using VIRSH to manage #{host}!!!!"
      logger.warn ""
      step "Reverting VM: #{host} to #{snap} on VM server #{vmserver}"
      system("lib/virsh_exec.exp #{vmserver} snapshot-revert #{host} #{snap}")
    end

  else

    skip_test "Skipping revert VM step"
  end
