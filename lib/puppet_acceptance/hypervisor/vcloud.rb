module PuppetAcceptance 
  class Vcloud < PuppetAcceptance::Hypervisor

    def initialize(vcloud_hosts, options, config)
      @options = options
      @config = config['CONFIG'].dup
      @logger = options[:logger]
      @vcloud_hosts = vcloud_hosts
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
      @vcloud_hosts.each_with_index do |h, i|
        # Generate a randomized hostname
        o = [('a'..'z'),('0'..'9')].map{|r| r.to_a}.flatten
        h['vmhostname'] = o[rand(25)] + (0...14).map{o[rand(o.length)]}.join

        if h['template'] =~ /\//
          templatefolders = h['template'].split('/')
          h['template'] = templatefolders.pop
        end

        @logger.notify "Deploying #{h['vmhostname']} (#{h.name}) to #{@config['folder']} from template '#{h['template']}'"

        vm = {}

        if templatefolders
          vm[h['template']] = vsphere_helper.find_folder(templatefolders.join('/')).find(h['template'])
        else
          vm = vsphere_helper.find_vms(h['template'])
        end

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
          :config        => configSpec,
          :location      => relocateSpec,
          :customization => vsphere_helper.find_customization( h['template'] ),
          :powerOn       => true,
          :template      => false
        )

        # Debug message if using a customization spec
        if vsphere_helper.find_customization( h['template'] )
          @logger.notify "Found customization spec for '#{h['template']}', will apply after boot"
        end

        # Deploy from specified template
        if (@vcloud_hosts.length == 1) or (i == @vcloud_hosts.length - 1)
          vm[h['template']].CloneVM_Task( :folder => vsphere_helper.find_folder(@config['folder']), :name => h['vmhostname'], :spec => spec ).wait_for_completion
        else
          vm[h['template']].CloneVM_Task( :folder => vsphere_helper.find_folder(@config['folder']), :name => h['vmhostname'], :spec => spec )
        end
      end
      @logger.notify 'Spent %.2f seconds deploying VMs' % (Time.now - start)

      start = Time.now
      @vcloud_hosts.each_with_index do |h, i|
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
      @vcloud_hosts.each_with_index do |h, i|
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
            # Allow extra time for [Windows] hosts using customization templates
            if vsphere_helper.find_customization( h['template'] )
              if try <= 20
                sleep wait
                try += 1
              else
                raise "DNS resolution failed after #{wait} seconds"
              end
            else
              raise "DNS resolution failed after #{wait} seconds"
            end
          end
        end
      end
      @logger.notify "Spent %.2f seconds waiting for DNS resolution" % (Time.now - start)

      vsphere_helper.close 
    end

    def cleanup
      @logger.notify "Destroying vagrant boxes"
      vsphere_credentials = VsphereHelper.load_config

      @logger.notify "Connecting to vSphere at #{vsphere_credentials[:server]}" +
        " with credentials for #{vsphere_credentials[:user]}"

      vsphere_helper = VsphereHelper.new( vsphere_credentials )

      vm_names = @vcloud_hosts.map {|h| h['vmhostname'] }.compact
      if @vcloud_hosts.length != vm_names.length
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

  end
end
