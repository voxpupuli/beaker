require 'time'

module Beaker
  class GoogleCompute < Beaker::Hypervisor

    SLEEPWAIT = 5
    #number of hours before an instance is considered a zombie
    ZOMBIE = 3

    def initialize(google_hosts, options)
      @options = options
      @logger = options[:logger]
      @google_hosts = google_hosts
      @firewall = ''
      @gce_helper = GoogleComputeHelper.new(options)
    end

    def allow_root_login host
      @logger.debug "Update /etc/ssh/sshd_config to allow root login"
      host.exec(Command.new("sudo su -c \"sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config\""), {:pty => true})
      #restart sshd
      if host['platform'] =~ /debian|ubuntu/
        host.exec(Command.new("sudo su -c \"service ssh restart\""), {:pty => true})
      elsif host['platform'] =~ /centos|el-|redhat|fedora/
        host.exec(Command.new("sudo su -c \"service sshd restart\""), {:pty => true})
      else
        raise "Attempting to update ssh on non-supported platform: #{host.name}: #{host['platform']}"
      end
    end

    def disable_se_linux_and_firewall host
      if host['platform'] =~ /centos/
        @logger.debug("Disabling se_linux on #{host.name}")
        host.exec(Command.new("sudo su -c \"setenforce 0\""), {:pty => true})
        host.exec(Command.new("sudo su -c \"/etc/init.d/iptables stop\""), {:pty => true})
      end
    end

    def provision
      try = 1
      attempts = @options[:timeout].to_i / SLEEPWAIT
      start = Time.now

      #get machineType resource, used my all instances
      machineType = @gce_helper.get_machineType(start, attempts)

      #set firewall to open pe ports
      network = @gce_helper.get_network(start, attempts)
      @firewall = generate_host_name
      @gce_helper.create_firewall(@firewall, network, start, attempts)

      @logger.debug("Created firewall #{@firewall}")


      @google_hosts.each do |host|
        img = @gce_helper.get_latest_image(host[:platform], start, attempts)
        host['diskname'] = generate_host_name
        disk = @gce_helper.create_disk(host['diskname'], img, start, attempts)
        @logger.debug("Created disk #{host.name}: #{host['diskname']}")

        #create new host name
        host['vmhostname'] = generate_host_name
        #add a new instance of the image
        instance = @gce_helper.create_instance(host['vmhostname'], img, machineType, disk, start, attempts)
        @logger.debug("Created instance #{host.name}: #{host['vmhostname']}")

        #get ip for this host
        host['ip'] = instance['networkInterfaces'][0]['accessConfigs'][0]['natIP']

        #configure ssh
        default_user = host['user']
        host['user'] = 'google_compute'

        disable_se_linux_and_firewall(host)
        copy_ssh_to_root(host)
        allow_root_login(host)
        host['user'] = default_user

        #shut down connection, will reconnect on next exec
        host.close

        @logger.debug("Instance ready: #{host['vmhostname']} for #{host.name}}")
      end
    end

    def cleanup()
      attempts = @options[:timeout].to_i / SLEEPWAIT
      start = Time.now

      @gce_helper.delete_firewall(@firewall, start, attempts) 

      @google_hosts.each do |host|
        @gce_helper.delete_instance(host['vmhostname'], start, attempts)
        @logger.debug("Deleted instance #{host['vmhostname']} for #{host.name}")
        @gce_helper.delete_disk(host['diskname'], start, attempts)
        @logger.debug("Deleted disk #{host['diskname']} for #{host.name}")
      end

    end

    def kill_zombies(max_age = ZOMBIE)
      now = start = Time.now
      attempts = @options[:timeout].to_i / SLEEPWAIT

      #get rid of old instances 
      instances = @gce_helper.list_instances(start, attempts)
      if instances
        instances.each do |instance|
          created = Time.parse(instance['creationTimestamp'])
          alive = (now - created ) /60 /60
          if alive >= max_age
            #kill it with fire!
            @logger.debug("Deleting zombie instance #{instance['name']}")
            @gce_helper.delete_instance( instance['name'], start, attempts )
          end
        end
      else 
        @logger.debug("No zombie instances found")
      end
      #get rid of old disks
      disks = @gce_helper.list_disks(start, attempts)
      if disks
        disks.each do |disk|
          created = Time.parse(disk['creationTimestamp'])
          alive = (now - created ) /60 /60
          if alive >= max_age
            #kill it with fire!
            @logger.debug("Deleting zombie disk #{disk['name']}")
            @gce_helper.delete_disk( disk['name'], start, attempts )
          end
        end
      else
        @logger.debug("No zombie disks found")
      end
      #get rid of non-default firewalls
      firewalls = @gce_helper.list_firewalls( start, attempts)

      if firewalls and not firewalls.empty?
        firewalls.each do |firewall|
          @logger.debug("Deleting non-default firewall #{firewall['name']}")
          @gce_helper.delete_firewall( firewall['name'], start, attempts )
        end
      else
        @logger.debug("No zombie firewalls found")
      end

    end

  end
end
