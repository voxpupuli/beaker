module Beaker 
  class Vcloud < Beaker::Hypervisor

    def initialize(vcloud_hosts, options)
      @options = options
      @logger = options[:logger]
      @vcloud_hosts = vcloud_hosts
      require 'yaml' unless defined?(YAML)

      raise 'You must specify a datastore for vCloud instances!' unless @options['datastore']
      raise 'You must specify a resource pool for vCloud instances!' unless @options['resourcepool']
      raise 'You must specify a folder for vCloud instances!' unless @options['folder']

      if @options['pooling_api']
        require 'json'
        require 'net/http'

        start = Time.now
        @vcloud_hosts.each_with_index do |h, i|
          if h['template'] =~ /\//
            templatefolders = h['template'].split('/')
            h['template'] = templatefolders.pop
          end

          @logger.notify "Requesting '#{h['template']}' VM from vCloud host pool"

          uri = URI.parse(@options['pooling_api']+'/vm/'+h['template'])

          http = Net::HTTP.new( uri.host, uri.port )
          request = Net::HTTP::Post.new(uri.request_uri)

          request.set_form_data({'pool' => @options['resourcepool'], 'folder' => 'foo'})

          begin
            response = http.request(request)
          rescue
            raise "Unable to connect to '#{uri}'!"
          end

          begin
            h['vmhostname'] = JSON.parse(response.body)[h.name]['hostname']
          rescue
            raise "Malformed data received from '#{uri}'!"
          end

          @logger.notify "Using available vCloud host '#{h['vmhostname']}' (#{h.name})"
        end

        @logger.notify 'Spent %.2f seconds grabbing VMs' % (Time.now - start)
      else
        vsphere_credentials = VsphereHelper.load_config(@options[:dot_fog])

        @logger.notify "Connecting to vSphere at #{vsphere_credentials[:server]}" +
          " with credentials for #{vsphere_credentials[:user]}"

        vsphere_helper = VsphereHelper.new( vsphere_credentials )
        vsphere_vms = {}

        try = 1
        attempts = @options[:timeout].to_i / 5

        start = Time.now
        @vcloud_hosts.each_with_index do |h, i|
          # Generate a randomized hostname
          o = [('a'..'z'),('0'..'9')].map{|r| r.to_a}.flatten
          h['vmhostname'] = o[rand(25)] + (0...14).map{o[rand(o.length)]}.join

          if h['template'] =~ /\//
            templatefolders = h['template'].split('/')
            h['template'] = templatefolders.pop
          end

          @logger.notify "Deploying #{h['vmhostname']} (#{h.name}) to #{@options['folder']} from template '#{h['template']}'"

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

          # Are we using a customization spec?
          customizationSpec = vsphere_helper.find_customization( h['template'] )

          if customizationSpec
            # Print a logger message if using a customization spec
            @logger.notify "Found customization spec for '#{h['template']}', will apply after boot"
          end

          # Put the VM in the specified folder and resource pool
          relocateSpec = RbVmomi::VIM.VirtualMachineRelocateSpec(
            :datastore    => vsphere_helper.find_datastore(@options['datastore']),
            :pool         => vsphere_helper.find_pool(@options['resourcepool']),
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

          # Deploy from specified template
          if (@vcloud_hosts.length == 1) or (i == @vcloud_hosts.length - 1)
            vm[h['template']].CloneVM_Task( :folder => vsphere_helper.find_folder(@options['folder']), :name => h['vmhostname'], :spec => spec ).wait_for_completion
          else
            vm[h['template']].CloneVM_Task( :folder => vsphere_helper.find_folder(@options['folder']), :name => h['vmhostname'], :spec => spec )
          end
        end

        @logger.notify 'Spent %.2f seconds deploying VMs' % (Time.now - start)

        try = (Time.now - start) / 5

        start = Time.now
        @vcloud_hosts.each_with_index do |h, i|
          @logger.notify "Booting #{h['vmhostname']} (#{h.name}) and waiting for it to register with vSphere"

          until
            vsphere_helper.find_vms(h['vmhostname'])[h['vmhostname']].summary.guest.toolsRunningStatus == 'guestToolsRunning' and
            vsphere_helper.find_vms(h['vmhostname'])[h['vmhostname']].summary.guest.ipAddress != nil
            if try <= attempts
              sleep 5
              try += 1
            else
              raise "vSphere registration failed after #{@options[:timeout].to_i} seconds"
            end
          end
        end
        @logger.notify "Spent %.2f seconds booting and waiting for vSphere registration" % (Time.now - start)

        start = Time.now
        @vcloud_hosts.each_with_index do |h, i|
          @logger.notify "Waiting for #{h['vmhostname']} DNS resolution"

          begin
            Socket.getaddrinfo(h['vmhostname'], nil)
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
        @logger.notify "Spent %.2f seconds waiting for DNS resolution" % (Time.now - start)

        vsphere_helper.close 
      end
    end

    def cleanup
      if @options['pooling_api']
        require 'json'
        require 'net/http'

        vm_names = @vcloud_hosts.map {|h| h['vmhostname'] }.compact
        if @vcloud_hosts.length != vm_names.length
          @logger.warn "Some hosts did not have vmhostname set correctly! This likely means VM provisioning was not successful"
        end

        start = Time.now
        vm_names.each do |name|
          @logger.notify "Handing '#{name}' back to pooling API for VM destruction"

          uri = URI.parse(@options['pooling_api']+'/vm/'+name)

          http = Net::HTTP.new( uri.host, uri.port )
          request = Net::HTTP::Delete.new(uri.request_uri)

          begin
            response = http.request(request)
          rescue
            raise "Unable to connect to '#{uri}'!"
          end
        end 

        @logger.notify "Spent %.2f seconds cleaning up" % (Time.now - start)
      else
        @logger.notify "Destroying vCloud boxes"
        vsphere_credentials = VsphereHelper.load_config(@options[:dot_fog])

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
end
