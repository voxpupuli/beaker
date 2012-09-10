
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
  snap = 'git' if options[:type] == 'manual'  # Sweet, sweet consistency

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

  elsif options[:vmrun] == 'fusion'
    require 'rubygems' unless defined?(Gem)
    begin
      require 'fission'
    rescue LoadError
      fail_test "Unable to load fission, please ensure its installed"
    end

    available = Fission::VM.all.data.collect{|vm| vm.name}.sort.join(", ")
    logger.notify "Available VM names: #{available}"

    hosts.each do |host|
      fission_opts = host.defaults["fission"] || {}
      vm_name = host.defaults["vmname"] || host.name
      vm = Fission::VM.new vm_name
      fail_test("Could not find vm #{vm_name} for #{host}") unless vm.exists?

      available_snapshots = vm.snapshots.data.sort.join(", ")
      logger.notify "Available snapshots for #{host}: #{available_snapshots}"
      snap_name = fission_opts["snapshot"] || snap
      fail_test "No snapshot specified for #{host}" unless snap_name
      fail_test("Could not find snapshot #{snap_name} for host #{host}") unless vm.snapshots.data.include? snap_name

      logger.notify "Reverting #{host} to snapshot #{snap_name}"
      start = Time.now
      vm.revert_to_snapshot snap_name
      while vm.running?.data
        sleep 1
      end
      time = Time.now - start
      logger.notify "Spent %f.2 seconds reverting" % time

      logger.notify "Resuming #{host}"
      start = Time.now
      vm.start :headless => true
      until vm.running?.data
        sleep 1
      end
      time = Time.now - start
      logger.notify "Spent %f.2 seconds resuming VM" % time
    end
  elsif options[:vmrun] == 'blimpy'
    require 'rubygems'
    require 'blimpy'

    AMI = YAML.load_file('config/image_templates/ec2.yaml')["AMI"]
    if options[:type] =~ /pe/
      image_type = :pe
    else
      image_type = :foss
    end

    fleet = Blimpy.fleet do |fleet|
      hosts.each do |host|
        amisize = host["amisize"] || 'm1.small'
        ami = AMI[host['platform']]
        fleet.add(:aws) do |ship|
          ship.name = host.name
          ship.ports = [22, 80, 8080] #TODO pick these based on the role?
          ship.image_id = ami[:image][image_type]
          ship.flavor = amisize
          ship.region = ami[:region]
          ship.username = 'root'
        end
      end
    end

    fleet.start

    # Configure our nodes to match the blimp fleet
    # Also generate hosts entries for the fleet, since we're iterating
    etc_hosts = "127.0.0.1\tlocalhost localhost.localdomain\n"
    fleet.ships.each do |ship|
      ship.wait_for_sshd
      name = ship.name
      host = hosts.select { |host| host.name == name }[0]
      host['ip'] = ship.dns
      on host, "hostname #{name}"
      on host, "ip a|awk '/g/{print$2}' | cut -d/ -f1 | head -1"
      ip = stdout.chomp
      etc_hosts += "#{ip}\t#{name}\n"
    end

    # Send our hosts information to the nodes
    on hosts, "echo '#{etc_hosts}' > /etc/hosts"

  elsif options[:vmrun]
    raise ArgumentError, "Invalid value for vmrun: #{options[:vmrun]}"
  else
    skip_test "Skipping revert VM step"
  end
