module PuppetAcceptance
  module Utils
    class VMControl
      HYPERVISOR_TYPES = ['solaris', 'blimpy', 'vsphere', 'fusion', 'aix', 'vcloud']

      def initialize(options, hosts, config)
        @logger = options[:logger]
        @hosts = hosts
        @options = options.dup
        @config = config['CONFIG'].dup
        @virtual_machines = {}
        @hosts.each do |host|
          #check to see if there are any specified hypervisors/snapshots
          hypervisor = host['hypervisor'] || options[:hypervisor]
          if hypervisor && (host.has_key?('revert') ? host['revert'] : true) #obey config file revert, defaults to reverting vms
            raise "Invalid hypervisor: #{hypervisor} (#{host})" unless HYPERVISOR_TYPES.include? hypervisor
            @logger.debug "Hypervisor for #{host} is #{host['hypervisor'] || 'default' }, and I'm going to use #{hypervisor}"
            @virtual_machines[hypervisor] = [] unless @virtual_machines[hypervisor]
            @virtual_machines[hypervisor] << host
          end
        end
      end

      # NOTE: this code is shamelessly stolen from facter's 'domain' fact, but
      # we don't have access to facter at this point in the run.  Also, this
      # utility method should perhaps be moved to a more central location in the
      # framework.
      def get_domain_name(host)
        domain = nil
        search = nil
        resolv_conf = host.exec(Command.new("cat /etc/resolv.conf")).stdout
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

      def revert_aix(aix_hosts, snap)
        fog_file = nil
        if File.exists?( File.join(ENV['HOME'], '.fog') )
          fog_file = YAML.load_file( File.join(ENV['HOME'], '.fog') )
        end
        raise "Cant load ~/.fog config" unless fog_file

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

        hyperconfig = PuppetAcceptance::TestConfig.new( hyperconf, @options )

        @logger.notify "Connecting to hypervisor at #{hypername}"
        hypervisor = PuppetAcceptance::Host.create( hypername, @options, hyperconfig )

        # This is a hack; we want to pull from the 'foss' snapshot
        # Not used for AIX...yet
        snap = 'foss' if snap == 'git'

        aix_hosts.each do |host|
          vm_name = host['vmname'] || host.name

          @logger.notify "Reverting #{vm_name} to snapshot #{snap}"
          start = Time.now
          # Restore AIX image, ID'd by the hostname
          hypervisor.exec(Command.new("cd pe-aix && rake restore:#{host.name}"))
          time = Time.now - start
          @logger.notify "Spent %.2f seconds reverting" % time
        end
        hypervisor.close
      end

      def revert_solaris(solaris_hosts, snap)
        fog_file = nil
        if File.exists?( File.join(ENV['HOME'], '.fog') )
          fog_file = YAML.load_file( File.join(ENV['HOME'], '.fog') )
        end
        raise "Cant load ~/.fog config" unless fog_file

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

        hyperconfig = PuppetAcceptance::TestConfig.new( hyperconf, @options )

        @logger.notify "Connecting to hypervisor at #{hypername}"
        hypervisor = PuppetAcceptance::Host.create( hypername, @options, hyperconfig )

        # This is a hack; we want to pull from the 'foss' snapshot
        snap = 'foss' if snap == 'git'

        solaris_hosts.each do |host|
          vm_name = host['vmname'] || host.name

          @logger.notify "Reverting #{vm_name} to snapshot #{snap}"
          start = Time.now
          hypervisor.exec(Command.new("sudo /sbin/zfs rollback -Rf #{vmpath}/#{vm_name}@#{snap}"))
          snappaths.each do |spath|
            @logger.notify "Reverting #{vm_name}/#{spath} to snapshot #{snap}"
            hypervisor.exec(Command.new("sudo /sbin/zfs rollback -Rf #{vmpath}/#{vm_name}/#{spath}@#{snap}"))
          end
          time = Time.now - start
          @logger.notify "Spent %.2f seconds reverting" % time

          @logger.notify "Booting #{vm_name}"
          start = Time.now
          hypervisor.exec(Command.new("sudo /sbin/zoneadm -z #{vm_name} boot"))
          @logger.notify "Spent %.2f seconds booting #{vm_name}" % (Time.now - start)
        end
        hypervisor.close
      end

      def revert_vsphere(vsphere_hosts, snap)
        require 'yaml' unless defined?(YAML)
        vsphere_credentials = VsphereHelper.load_config

        @logger.notify "Connecting to vSphere at #{vsphere_credentials[:server]}" +
          " with credentials for #{vsphere_credentials[:user]}"

        vsphere_helper = VsphereHelper.new( vsphere_credentials )

        vsphere_vms = {}
        vsphere_hosts.each do |h|
          name = h["vmname"] || h.name
          real_snap = h["snapshot"] || snap
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
      end #revert_vsphere

      def revert_fusion(fusion_hosts, snap)
        require 'rubygems' unless defined?(Gem)
        begin
          require 'fission'
        rescue LoadError
          raise "Unable to load fission, please ensure it is installed!"
        end

        available = Fission::VM.all.data.collect{|vm| vm.name}.sort.join(", ")
        @logger.notify "Available VM names: #{available}"

        fusion_hosts.each do |host|
          fission_opts = host.defaults["fission"] || {}
          vm_name = host.defaults["vmname"] || host.name
          vm = Fission::VM.new vm_name
          raise "Could not find VM '#{vm_name}' for #{host}!" unless vm.exists?

          available_snapshots = vm.snapshots.data.sort.join(", ")
          @logger.notify "Available snapshots for #{host}: #{available_snapshots}"
          snap_name = host["snapshot"] || fission_opts["snapshot"] || snap
          raise "No snapshot specified for #{host}" unless snap_name
          raise "Could not find snapshot '#{snap_name}' for host #{host}!" unless vm.snapshots.data.include? snap_name

          @logger.notify "Reverting #{host} to snapshot '#{snap_name}'"
          start = Time.now
          vm.revert_to_snapshot snap_name
          while vm.running?.data
            sleep 1
          end
          time = Time.now - start
          @logger.notify "Spent %.2f seconds reverting" % time

          @logger.notify "Resuming #{host}"
          start = Time.now
          vm.start :headless => true
          until vm.running?.data
            sleep 1
          end
          time = Time.now - start
          @logger.notify "Spent %.2f seconds resuming VM" % time
        end
      end #revert_fusion

      def revert_blimpy(blimpy_hosts, snap, hosts)
        require 'rubygems' unless defined?(Gem)
        require 'blimpy'

        ami_spec= YAML.load_file('config/image_templates/ec2.yaml')["AMI"]
        #HACK HACK HACK - get type out of here
        if @options[:type] =~ /pe/
          image_type = :pe
        else
          image_type = :foss
        end

        fleet = Blimpy.fleet do |fleet|
          blimpy_hosts.each do |host|
            amitype = host['vmname'] || host['platform']
            amisize = host['amisize'] || 'm1.small'
            ami = ami_spec[amitype]
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
            @logger.notify("Calling fleet.destroy, sleeping #{sleep_time} seconds and retrying fleet.start due to Fog::Errors::Error (#{ex.message}), retry attempt #{fleet_retries}.")
            begin
              timeout(30) do
                fleet.destroy
              end
            rescue
            end
            sleep rand(20)
            retry
          else
            @logger.error("Retried Fog #{fleet_retries} times, giving up and throwing the exception")
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
          host.exec(Command.new("hostname #{name}"))
          ip = host.exec(Command.new("ip a|awk '/g/{print$2}' | cut -d/ -f1 | head -1")).stdout.chomp
          domain = get_domain_name(host)
          etc_hosts += "#{ip}\t#{name}\t#{name}.#{domain}\n"
        end

        # Send our hosts information to the nodes
        blimpy_hosts.each do |host|
          host.exec(Command.new("echo '#{etc_hosts}' > /etc/hosts"))
        end
      end #revert_blimpy

      def revert_vcloud(vcloud_hosts, snap)
          require 'yaml' unless defined?(YAML)
      
          raise 'You must specify a datastore for vCloud instances!' unless @config['datastore']
          raise 'You must specify a resource pool for vCloud instances!' unless @config['resourcepool']
          raise 'You must specify a folder for vCloud instances!' unless @config['folder']
      
          vsphere_credentials = VsphereHelper.load_config
      
          @logger.notify "Connecting to vSphere at #{vsphere_credentials[:server]}" +
            " with credentials for #{vsphere_credentials[:user]}"
      
          vsphere_helper = VsphereHelper.new( vsphere_credentials )
          vsphere_vms = {}
      
          start = Time.now
          vcloud_hosts.each_with_index do |h, i|
            # Generate a randomized hostname
            o = [('a'..'z'),('0'..'9')].map{|r| r.to_a}.flatten
            h['vmhostname'] = (0...15).map{o[rand(o.length)]}.join
      
            @logger.notify "Deploying #{h['vmhostname']} (#{h.name}) to #{@config['folder']} from template '#{h['template']}'"

            vm = vsphere_helper.find_vms(h['template'])
            if vm.length == 0
              raise "Unable to find template '#{h['template']}'!"
            end

            # Add VM annotation
            configSpec = RbVmomi::VIM.VirtualMachineConfigSpec(
              :annotation =>
                'Base template:  ' + h['template'] + "\n" +
                'Creation time:  ' + Time.now.strftime("%Y-%m-%d %H:%M") + "\n\n" +
                'CI build link:  ' + ( ENV['BUILD_URL'] || 'Deployed independently of CI' )
            )

            # Put the VM in the specified folder and resource pool
            relocateSpec = RbVmomi::VIM.VirtualMachineRelocateSpec(
              :datastore    => vsphere_helper.find_datastore(@config['datastore']),
              :pool         => vsphere_helper.find_pool(@config['resourcepool']),
              :diskMoveType => :moveChildMostDiskBacking
            )
            spec = RbVmomi::VIM.VirtualMachineCloneSpec(
              :config   => configSpec,
              :location => relocateSpec,
              :powerOn  => true,
              :template => false
            )
      
            # Deploy from specified template
            if (vcloud_hosts.length == 1) or (i == vcloud_hosts.length - 1)
              vm[h['template']].CloneVM_Task( :folder => vsphere_helper.find_folder(@config['folder']), :name => h['vmhostname'], :spec => spec ).wait_for_completion
            else
              vm[h['template']].CloneVM_Task( :folder => vsphere_helper.find_folder(@config['folder']), :name => h['vmhostname'], :spec => spec )
            end
          end
          @logger.notify 'Spent %.2f seconds deploying VMs' % (Time.now - start)
      
          start = Time.now
          vcloud_hosts.each_with_index do |h, i|
            @logger.notify "Booting #{h['vmhostname']} (#{h.name}) and waiting for it to register with vSphere"
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
                raise "vSphere registration failed after #{wait} seconds"
              end
            end
          end
          @logger.notify "Spent %.2f seconds booting and waiting for vSphere registration" % (Time.now - start)
      
          start = Time.now
          vcloud_hosts.each_with_index do |h, i|
            @logger.notify "Waiting for #{h['vmhostname']} DNS resolution"
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
                raise "DNS resolution failed after #{wait} seconds"
              end
            end
          end
          @logger.notify "Spent %.2f seconds waiting for DNS resolution" % (Time.now - start)
      
          vsphere_helper.close
      end #revert_vcloud

      def revert
        #check to see if we are using any vms
        if not @virtual_machines
          @logger.debug 'no virtual machines specified'
          return
        end

        #HACK HACK HACK - get type out of here
        snap = @options[:snapshot] || @options[:type]
        snap = 'git' if snap == 'gem'  # Sweet, sweet consistency
        snap = 'git' if snap == 'manual'  # Sweet, sweet consistency
        raise "You must specifiy a snapshot when using pe_noop" unless snap != 'pe_noop'

        @virtual_machines.keys.each do |type|
          case type
            when /aix/
              revert_aix(@virtual_machines[type], snap)
            when /solaris/
              revert_solaris(@virtual_machines[type], snap)
            when /vsphere/
              revert_vsphere(@virtual_machines[type], snap)
            when /fusion/
              revert_fusion(@virtual_machines[type], snap)
            when /blimpy/
              revert_blimpy(@virtual_machines[type], snap, @hosts)
            when /vcloud/
              revert_vcloud(@virtual_machines[type], snap)
          end
        end
        @logger.debug "virtual machines reverted and ready"
      rescue => e
        report_and_raise(@logger, e, "revert vms")
      end #revert

      def cleanup_blimpy(blimpy_hosts)
        fleet = Blimpy.fleet do |fleet|
          blimpy_hosts.each do |host|
            fleet.add(:aws) do |ship|
              ship.name = host.name
            end
          end
        end

        fleet.destroy
      end #cleanup_blimpy

      def cleanup_vsphere(vsphere_hosts)
        vsphere_credentials = VsphereHelper.load_config

        @logger.notify "Connecting to vSphere at #{vsphere_credentials[:server]}" +
          " with credentials for #{vsphere_credentials[:user]}"

        vsphere_helper = VsphereHelper.new( vsphere_credentials )

        vm_names = vsphere_hosts.map {|h| h['vmname'] || h.name }
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
      end #cleanup_vsphere

      def cleanup_vcloud(vcloud_hosts)
        vsphere_credentials = VsphereHelper.load_config

        @logger.notify "Connecting to vSphere at #{vsphere_credentials[:server]}" +
          " with credentials for #{vsphere_credentials[:user]}"

        vsphere_helper = VsphereHelper.new( vsphere_credentials )

        vm_names = vcloud_hosts.map {|h| h['vmhostname'] }.compact
        if vcloud_hosts.length != vm_names.length
          @logger.warn "Some hosts did not have vmhostname set correctly! This likely means VM provisioning was not successful"
        end
        vms = vsphere_helper.find_vms vm_names
        vm_names.each do |name|
          unless vm = vms[name]
            raise "Couldn't find VM #{name} in vSphere!"
          end

          if vm.runtime.powerState == 'poweredOn'
            @logger.notify "Shutting down #{vm.name}"
            start = Time.now
            vm.PowerOffVM_Task.wait_for_completion
            @logger.notify "Spent %.2f seconds halting #{vm.name}" % (Time.now - start)
          end

          start = Time.now
          vm.Destroy_Task
          @logger.notify "Spent %.2f seconds destroying #{vm.name}" % (Time.now - start)
        end

        vsphere_helper.close
      end

      def cleanup
        if not @options[:preserve_hosts]
          @virtual_machines.keys.each do |type|
            case type
              when /blimpy/
                cleanup_blimpy(@virtual_machines[type])
              when /vsphere/
                cleanup_vsphere(@virtual_machines[type])
              when /vcloud/
                cleanup_vcloud(@virtual_machines[type])
            end
          end
          @logger.debug "virtual machines cleaned up"
        end
      rescue => e
        report_and_raise(@logger, e, "cleanup vms")
      end
    end
  end
end
