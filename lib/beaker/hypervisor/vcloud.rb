require 'yaml' unless defined?(YAML)

module Beaker
  class Vcloud < Beaker::Hypervisor

    def initialize(vcloud_hosts, options)
      @options = options
      @logger = options[:logger]
      @hosts = vcloud_hosts

      raise 'You must specify a datastore for vCloud instances!' unless @options['datastore']
      raise 'You must specify a folder for vCloud instances!' unless @options['folder']
      @vsphere_credentials = VsphereHelper.load_config(@options[:dot_fog])
    end

    def connect_to_vsphere
      @logger.notify "Connecting to vSphere at #{@vsphere_credentials[:server]}" +
        " with credentials for #{@vsphere_credentials[:user]}"

      @vsphere_helper = VsphereHelper.new( @vsphere_credentials )
    end

    def wait_for_dns_resolution host, try, attempts
      @logger.notify "Waiting for #{host['vmhostname']} DNS resolution"
      begin
        Socket.getaddrinfo(host['vmhostname'], nil)
      rescue
        if try <= attempts
          sleep 5
          try += 1

          retry
        else
          raise "DNS resolution failed after #{@options[:timeout].to_i} seconds"
        end
      end
    end

    def booting_host host, try, attempts
      @logger.notify "Booting #{host['vmhostname']} (#{host.name}) and waiting for it to register with vSphere"
      until
        @vsphere_helper.find_vms(host['vmhostname'])[host['vmhostname']].summary.guest.toolsRunningStatus == 'guestToolsRunning' and
        @vsphere_helper.find_vms(host['vmhostname'])[host['vmhostname']].summary.guest.ipAddress != nil
        if try <= attempts
          sleep 5
          try += 1
        else
          raise "vSphere registration failed after #{@options[:timeout].to_i} seconds"
        end
      end
    end

    def create_clone_spec host
      # Add VM annotation
      configSpec = RbVmomi::VIM.VirtualMachineConfigSpec(
        :annotation =>
          'Base template:  ' + host['template'] + "\n" +
          'Creation time:  ' + Time.now.strftime("%Y-%m-%d %H:%M") + "\n\n" +
          'CI build link:  ' + ( ENV['BUILD_URL'] || 'Deployed independently of CI' ) +
          'department:     ' + @options[:department] +
          'project:        ' + @options[:project]
      )

      # Are we using a customization spec?
      customizationSpec = @vsphere_helper.find_customization( host['template'] )

      if customizationSpec
        # Print a logger message if using a customization spec
        @logger.notify "Found customization spec for '#{host['template']}', will apply after boot"
      end

      # Put the VM in the specified folder and resource pool
      relocateSpec = RbVmomi::VIM.VirtualMachineRelocateSpec(
        :datastore    => @vsphere_helper.find_datastore(@options['datastore']),
        :pool         => @options['resourcepool'] ? @vsphere_helper.find_pool(@options['resourcepool']) : nil,
        :diskMoveType => :moveChildMostDiskBacking
      )

      # Create a clone spec
      spec = RbVmomi::VIM.VirtualMachineCloneSpec(
        :config        => configSpec,
        :location      => relocateSpec,
        :customization => customizationSpec,
        :powerOn       => true,
        :template      => false
      )
      spec
    end

    def provision
      connect_to_vsphere
      begin
        vsphere_vms = {}

        try = 1
        attempts = @options[:timeout].to_i / 5

        start = Time.now
        tasks = []
        @hosts.each_with_index do |h, i|
          if h['name']
            h['vmhostname'] = h['name']
          else
            h['vmhostname'] = generate_host_name
          end

          if h['template'] =~ /\//
            templatefolders = h['template'].split('/')
            h['template'] = templatefolders.pop
          end

          @logger.notify "Deploying #{h['vmhostname']} (#{h.name}) to #{@options['folder']} from template '#{h['template']}'"

          vm = {}

          if templatefolders
            vm[h['template']] = @vsphere_helper.find_folder(templatefolders.join('/')).find(h['template'])
          else
            vm = @vsphere_helper.find_vms(h['template'])
          end

          if vm.length == 0
            raise "Unable to find template '#{h['template']}'!"
          end

          spec = create_clone_spec(h)

          # Deploy from specified template
          tasks << vm[h['template']].CloneVM_Task( :folder => @vsphere_helper.find_folder(@options['folder']), :name => h['vmhostname'], :spec => spec )
        end
        try = (Time.now - start) / 5
        @vsphere_helper.wait_for_tasks(tasks, try, attempts)
        @logger.notify 'Spent %.2f seconds deploying VMs' % (Time.now - start)

        try = (Time.now - start) / 5
        duration = run_and_report_duration do
          @hosts.each_with_index do |h, i|
            booting_host(h, try, attempts)
          end
        end
        @logger.notify "Spent %.2f seconds booting and waiting for vSphere registration" % duration

        try = (Time.now - start) / 5
        duration = run_and_report_duration do
          @hosts.each_with_index do |h, i|
            wait_for_dns_resolution(h, try, attempts)
          end
        end
        @logger.notify "Spent %.2f seconds waiting for DNS resolution" % duration
      rescue => e
        @vsphere_helper.close
        report_and_raise(@logger, e, "Vcloud.provision")
      end
    end

    def cleanup
      @logger.notify "Destroying vCloud boxes"
      connect_to_vsphere

      vm_names = @hosts.map {|h| h['vmhostname'] }.compact
      if @hosts.length != vm_names.length
        @logger.warn "Some hosts did not have vmhostname set correctly! This likely means VM provisioning was not successful"
      end
      vms = @vsphere_helper.find_vms vm_names
      begin
        vm_names.each do |name|
          unless vm = vms[name]
            @logger.warn "Unable to cleanup #{name}, couldn't find VM #{name} in vSphere!"
            next
          end

          if vm.runtime.powerState == 'poweredOn'
            @logger.notify "Shutting down #{vm.name}"
            duration = run_and_report_duration do
              vm.PowerOffVM_Task.wait_for_completion
            end
            @logger.notify "Spent %.2f seconds halting #{vm.name}" % duration
          end

          duration = run_and_report_duration do
            vm.Destroy_Task
          end
          @logger.notify "Spent %.2f seconds destroying #{vm.name}" % duration

        end
      rescue RbVmomi::Fault => ex
        if ex.fault.is_a?(RbVmomi::VIM::ManagedObjectNotFound)
          #it's already gone, don't bother trying to delete it
          name = vms.key(ex.fault.obj)
          vms.delete(name)
          vm_names.delete(name)
          @logger.warn "Unable to destroy #{name}, it was not found in vSphere"
          retry
        end
      end
      @vsphere_helper.close
    end

  end
end
