test_name "Revert VMs" do

  #check to see if we are running with --no-revert
  skip_test 'Running with --no-revert, will not revert vms'  unless options[:revert]

  #check to see if there are any specified hypervisors/snapshots
  VMRUN_TYPES = ['solaris', 'blimpy', 'vsphere', 'vcloud', 'fusion']
  virtual_machines = {}
  hosts.each do |host|
    hypervisor = host['hypervisor'] || options[:vmrun]
    if hypervisor && (host.has_key?('revert') ? host['revert'] : true) #obey config file revert, defaults to reverting vms
      fail_test "Invalid hypervisor: #{hypervisor} (#{host})" unless VMRUN_TYPES.include? hypervisor
      logger.debug "Hypervisor for #{host} is #{host['hypervisor'] || 'default' }, and I'm going to use #{hypervisor}"
      virtual_machines[hypervisor] = [] unless virtual_machines[hypervisor]
      virtual_machines[hypervisor] << host
    end
  end

  skip_test 'no virtual machines specified' unless virtual_machines

  # NOTE: this code is shamelessly stolen from facter's 'domain' fact, but
  # we don't have access to facter at this point in the run.  Also, this
  # utility method should perhaps be moved to a more central location in the
  # framework.
  def get_domain_name(host)
    domain = nil
    search = nil
    on host, "cat /etc/resolv.conf"
    resolv_conf = stdout
    resolv_conf.each_line { |line|
      if line =~ /^\s*domain\s+(\S+)/
        domain = $1
      elsif line =~ /^\s*search\s+(\S+)/
        search = $1
      end
    }
    return domain if domain
    return search if search
  end

  def amiports(host)
    roles = host['roles']
    ports = [22]

    if roles.include? 'database'
      ports << 8080
      ports << 8081
    end

    if roles.include? 'master'
      ports << 8140
    end

    if roles.include? 'dashboard'
      ports << 443
    end

    ports
  end


  snap = options[:snapshot] || options[:type]
  snap = 'git' if snap == 'gem'  # Sweet, sweet consistency
  snap = 'git' if snap == 'manual'  # Sweet, sweet consistency
  fail_test "You must specifiy a snapshot when using pe_noop" if snap == 'pe_noop'

  if virtual_machines['aix']
    fog_file = nil
    if File.exists?( File.join(ENV['HOME'], '.fog') )
      fog_file = YAML.load_file( File.join(ENV['HOME'], '.fog') )
    end
    fail_test "Cant load ~/.fog config" unless fog_file

    # Running the rake task on rpm-builder
    hypername = fog_file[:default][:aix_hypervisor_server]
    hyperconf = {
      'HOSTS'  => {
        hypername => { 'platform' => 'el-6-x86_64' }
      },
      'CONFIG' => {
        'user' => fog_file[:default][:aix_hypervisor_username] || ENV['USER'],
        'ssh'  => {
          :keys => fog_file[:default][:aix_hypervisor_keyfile] || "#{ENV['HOME']}/.ssh/id_rsa"
        }
      }
    }

    hyperconfig = PuppetAcceptance::TestConfig.new( hyperconf, options )

    logger.notify "Connecting to hypervisor at #{hypername}"
    hypervisor = PuppetAcceptance::Host.create( hypername, options, hyperconfig )

    # This is a hack; we want to pull from the 'foss' snapshot
    # Not used for AIX...yet
    snap = 'foss' if snap == 'git'

    virtual_machines['aix'].each do |host|
      vm_name = host['vmname'] || host.name

      logger.notify "Reverting #{vm_name} to snapshot #{snap}"
      start = Time.now
      # Restore AIX image, ID'd by the hostname
      on hypervisor, "cd pe-aix && rake restore:#{host.name}"
      time = Time.now - start
      logger.notify "Spent %.2f seconds reverting" % time
    end
    hypervisor.close
  end

  if virtual_machines['solaris']
    fog_file = nil
    if File.exists?( File.join(ENV['HOME'], '.fog') )
      fog_file = YAML.load_file( File.join(ENV['HOME'], '.fog') )
    end
    fail_test "Cant load ~/.fog config" unless fog_file

    hypername = fog_file[:default][:solaris_hypervisor_server]
    vmpath    = fog_file[:default][:solaris_hypervisor_vmpath]
    snappaths = fog_file[:default][:solaris_hypervisor_snappaths]

    hyperconf = {
      'HOSTS'  => {
        hypername => { 'platform' => 'solaris-11-sparc' }
      },
      'CONFIG' => {
        'user' => fog_file[:default][:solaris_hypervisor_username] || ENV['USER'],
        'ssh'  => {
          :keys => fog_file[:default][:solaris_hypervisor_keyfile] || "#{ENV['HOME']}/.ssh/id_rsa"
        }
      }
    }

    hyperconfig = PuppetAcceptance::TestConfig.new( hyperconf, options )

    logger.notify "Connecting to hypervisor at #{hypername}"
    hypervisor = PuppetAcceptance::Host.create( hypername, options, hyperconfig )

    # This is a hack; we want to pull from the 'foss' snapshot
    snap = 'foss' if snap == 'git'

    virtual_machines[solaris].each do |host|
      vm_name = host['vmname'] || host.name

      logger.notify "Reverting #{vm_name} to snapshot #{snap}"
      start = Time.now
      on hypervisor, "sudo /sbin/zfs rollback -Rf #{vmpath}/#{vm_name}@#{snap}"
      snappaths.each do |spath|
        logger.notify "Reverting #{vm_name}/#{spath} to snapshot #{snap}"
        on hypervisor, "sudo /sbin/zfs rollback -Rf #{vmpath}/#{vm_name}/#{spath}@#{snap}"
      end
      time = Time.now - start
      logger.notify "Spent %.2f seconds reverting" % time

      logger.notify "Booting #{vm_name}"
      start = Time.now
      on hypervisor, "sudo /sbin/zoneadm -z #{vm_name} boot"
      logger.notify "Spent %.2f seconds booting #{vm_name}" % (Time.now - start)
    end
    hypervisor.close
  end

  if virtual_machines['vsphere']
    require 'yaml' unless defined?(YAML)
    require File.expand_path(File.join(File.dirname(__FILE__),
                                       '..', '..','lib', 'puppet_acceptance',
                                       'utils', 'vsphere_helper'))

    vsphere_credentials = VsphereHelper.load_config

    logger.notify "Connecting to vsphere at #{vsphere_credentials[:server]}" +
      " with credentials for #{vsphere_credentials[:user]}"

    vsphere_helper = VsphereHelper.new( vsphere_credentials )

    vsphere_vms = {}
    virtual_machines['vsphere'].each do |h|
      name = h["vmname"] || h.name
      real_snap = h["snapshot"] || snap
      vsphere_vms[name] = real_snap
    end
    vms = vsphere_helper.find_vms(vsphere_vms.keys)
    vsphere_vms.each_pair do |name, snap|
      unless vm = vms[name]
        fail_test("Couldn't find VM #{name} in vSphere!")
      end

      snapshot = vsphere_helper.find_snapshot(vm, snap) or
        fail_test("Could not find snapshot #{snap} for vm #{vm.name}")

      logger.notify "Reverting #{vm.name} to snapshot #{snap}"
      start = Time.now
      # This will block for each snapshot...
      # The code to issue them all and then wait until they are all done sucks
      snapshot.RevertToSnapshot_Task.wait_for_completion

      time = Time.now - start
      logger.notify "Spent %.2f seconds reverting" % time

      unless vm.runtime.powerState == "poweredOn"
        logger.notify "Booting #{vm.name}"
        start = Time.now
        vm.PowerOnVM_Task.wait_for_completion
        logger.notify "Spent %.2f seconds booting #{vm.name}" % (Time.now - start)
      end
    end

    vsphere_helper.close
  end

  if virtual_machines['vcloud']
    require 'yaml' unless defined?(YAML)
    require File.expand_path(File.join(File.dirname(__FILE__),
                                       '..', '..','lib', 'puppet_acceptance',
                                       'utils', 'vsphere_helper'))

    fail_test('You must specify a datastore for vCloud instances!') unless @config['datastore']
    fail_test('You must specify a resource pool for vCloud instances!') unless @config['resourcepool']
    fail_test('You must specify a folder for vCloud instances!') unless @config['folder']

    vsphere_credentials = VsphereHelper.load_config

    logger.notify "Connecting to vsphere at #{vsphere_credentials[:server]}" +
      " with credentials for #{vsphere_credentials[:user]}"

    vsphere_helper = VsphereHelper.new( vsphere_credentials )
    vsphere_vms = {}

    start = Time.now
    virtual_machines['vcloud'].each_with_index do |h, i|
      # Generate a randomized hostname
      o = [('a'..'z'),('0'..'9')].map{|r| r.to_a}.flatten
      h['vmhostname'] = (0...15).map{o[rand(o.length)]}.join

      logger.notify "Deploying #{h['vmhostname']} (#{h.name}) to #{@config['folder']} from template #{h['template']}"

      # Put the VM in the specified folder and resource pool
      relocateSpec = RbVmomi::VIM.VirtualMachineRelocateSpec(
        :datastore => vsphere_helper.find_datastore(@config['datastore']),
        :pool      => vsphere_helper.find_pool(@config['resourcepool'])
      )
      spec = RbVmomi::VIM.VirtualMachineCloneSpec(
        :location => relocateSpec,
        :powerOn  => true,
        :template => false
      )

      # Deploy from specified template
      vm = vsphere_helper.find_vms(h['template'])
      if (virtual_machines['vcloud'].length == 1) or (i == virtual_machines['vcloud'].length - 1)
        vm[h['template']].CloneVM_Task( :folder => vsphere_helper.find_folder(@config['folder']), :name => h['vmhostname'], :spec => spec ).wait_for_completion
      else
        vm[h['template']].CloneVM_Task( :folder => vsphere_helper.find_folder(@config['folder']), :name => h['vmhostname'], :spec => spec )
      end
    end
    logger.notify 'Spent %.2f seconds deploying VMs' % (Time.now - start)

    start = Time.now
    virtual_machines['vcloud'].each_with_index do |h, i|
      logger.notify "Waiting for #{h['vmhostname']} (#{h.name}) to register with vSphere"
      try = 1
      last_wait = 0
      wait = 1

      until
        vsphere_helper.find_vms(h['vmhostname'])[h['vmhostname']].summary.guest.toolsRunningStatus == 'guestToolsRunning' and
        vsphere_helper.find_vms(h['vmhostname'])[h['vmhostname']].summary.guest.ipAddress != nil
        if try <= 11
          sleep wait
          (last_wait, wait) = wait, last_wait + wait
          try += 1
        else
          fail_test("vSphere registration failed after #{wait} seconds")
        end
      end
    end
    logger.notify "Spent %.2f seconds waiting for vSphere registration" % (Time.now - start)

    start = Time.now
    virtual_machines['vcloud'].each_with_index do |h, i|
      logger.notify "Waiting for #{h['vmhostname']} DNS resolution"
      try = 1
      last_wait = 0
      wait = 1

      begin
        Socket.getaddrinfo(h['vmhostname'], nil)
      rescue
        if try <= 11
          sleep wait
          (last_wait, wait) = wait, last_wait + wait
          try += 1

          retry
        else
          fail_test("DNS resolution failed after #{wait} seconds")
        end
      end
    end
    logger.notify "Spent %.2f seconds waiting for DNS resolution" % (Time.now - start)

    vsphere_helper.close
  end

  if virtual_machines['fusion']
    require 'rubygems' unless defined?(Gem)
    begin
      require 'fission'
    rescue LoadError
      fail_test "Unable to load fission, please ensure its installed"
    end

    available = Fission::VM.all.data.collect{|vm| vm.name}.sort.join(", ")
    logger.notify "Available VM names: #{available}"

    virtual_machines['fusion'].each do |host|
      fission_opts = host.defaults["fission"] || {}
      vm_name = host.defaults["vmname"] || host.name
      vm = Fission::VM.new vm_name
      fail_test("Could not find vm #{vm_name} for #{host}") unless vm.exists?

      available_snapshots = vm.snapshots.data.sort.join(", ")
      logger.notify "Available snapshots for #{host}: #{available_snapshots}"
      snap_name = host["snapshot"] || fission_opts["snapshot"] || snap
      fail_test "No snapshot specified for #{host}" unless snap_name
      fail_test("Could not find snapshot #{snap_name} for host #{host}") unless vm.snapshots.data.include? snap_name

      logger.notify "Reverting #{host} to snapshot #{snap_name}"
      start = Time.now
      vm.revert_to_snapshot snap_name
      while vm.running?.data
        sleep 1
      end
      time = Time.now - start
      logger.notify "Spent %.2f seconds reverting" % time

      logger.notify "Resuming #{host}"
      start = Time.now
      vm.start :headless => true
      until vm.running?.data
        sleep 1
      end
      time = Time.now - start
      logger.notify "Spent %.2f seconds resuming VM" % time
    end
  end

  if virtual_machines['blimpy']
    require 'rubygems'
    require 'blimpy'

    AMI = YAML.load_file('config/image_templates/ec2.yaml')["AMI"]
    if options[:type] =~ /pe/
      image_type = :pe
    else
      image_type = :foss
    end

    fleet = Blimpy.fleet do |fleet|
      virtual_machines['blimpy'].each do |host|
        amitype = host['vmname'] || host['platform']
        amisize = host['amisize'] || 'm1.small'
        ami = AMI[amitype]
        fleet.add(:aws) do |ship|
          ship.name = host.name
          ship.ports = amiports(host)
          ship.image_id = ami[:image][image_type]
          ship.flavor = amisize
          ship.region = ami[:region]
          ship.username = 'root'
        end
      end
    end

    # Attempt to start the fleet, we wrap it with some error handling that deals
    # with generic Fog errors and retrying in case these errors are transient.
    fleet_retries = 0
    begin
      fleet.start
    rescue Fog::Errors::Error => ex
      fleet_retries += 1
      if fleet_retries <= 3
        sleep_time = rand(10) + 10
        logger.notify("Calling fleet.destroy, sleeping #{sleep_time} seconds and retrying fleet.start due to Fog::Errors::Error (#{ex.message}), retry attempt #{fleet_retries}.")
        begin
          timeout(30) do
            fleet.destroy
          end
        rescue
        end
        sleep rand(20)
        retry
      else
        logger.error("Retried Fog #{fleet_retries} times, giving up and throwing the exception")
        raise ex
      end
    end

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
      domain = get_domain_name(host)
      etc_hosts += "#{ip}\t#{name}\t#{name}.#{domain}\n"
    end

    # Send our hosts information to the nodes
    on hosts, "echo '#{etc_hosts}' > /etc/hosts"
  end
end
