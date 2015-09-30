module Beaker
  # A driver for LXC containers
  class Lxc < Beaker::Hypervisor
    # LXC initializtion
    #
    # @param [Array<Beaker::Host>] hosts Array of Beaker::Host objects
    # @param [Hash{Symbol=>String}] options Options hash
    def initialize(hosts, options)
      require 'lxc'

      @options = options
      @logger  = options[:logger]
      @hosts   = hosts
    end

    # Returns the default root password
    #
    # @return [String] the default root password
    def root_password
      'root'
    end

    # Provisions an LXC container
    #
    # @return [void]
    def provision
      @hosts.each do | host |
        @logger.notify "Provisioning LXC container #{host}"
        container = LXC::Container.new(host)

        template = host['template']
        arch = host['arch'] || "amd64"

        # Get template from config and divide it into image and release tag
        if match = template.match(/(.*):(.*)/)
          image = match.captures[0]
          release = match.captures[1]
        end

        begin
          # Create the container
          @logger.notify "Creating #{host} with #{template}"
          container.create("download", nil, {}, 0, ["-d", "#{image}", "-r", "#{release}", "-a", "#{arch}"])
        rescue Exception => e
          @logger.error "LXC container with name #{host} is already present, please remove it before provisioning."
          exit
        end

        # Configure container
        if host.has_key?('lxc_config')
          @logger.notify "Configuring #{host}"
          host['lxc_config'].each do |config_item|
            container.set_config_item(config_item[0].to_s, config_item[1])
          end
          container.save_config
        end

        # Start the container
        @logger.notify "Starting #{host}"
        container.start

        host.has_key?('extra_packages') || host['extra_packages'] = []
        # Install required packages, extra packages configured by user and configure and start sshd in the container
        @logger.notify "Attaching to #{host}"
        container.attach(:wait => true) do
          case host['platform']
          when /ubuntu/, /debian/
            puts `apt-get update`
            puts `apt-get install -y openssh-server openssh-client #{Beaker::HostPrebuiltSteps::DEBIAN_PACKAGES.join(' ')} #{host['extra_packages'].join(' ')}`
          when /^el-/, /centos/, /fedora/, /redhat/, /eos/
            # HACK to fix the /run
            if release =~  /7/
              puts `cp -fr /var/run/* /run/ && rm -frv /var/run >/dev/null && ln -s /run /var/run`
            end
            puts `ifup eth0`
            puts `yum clean all`
            puts `yum install -y sudo initscripts openssh-server openssh-clients #{Beaker::HostPrebuiltSteps::UNIX_PACKAGES.join(' ')} #{host['extra_packages'].join(' ')}`
            if release =~ /7/
              puts `sed -ri 's/^#?UseDNS .*/UseDNS no/' /etc/ssh/sshd_config`
              puts `systemctl start sshd`
            else
              puts `service sshd start`
            end
          when /opensuse/, /sles/
            puts `zypper -n in openssh #{Beaker::HostPrebuiltSteps::SLES_PACKAGES.join(' ')} #{host['extra_packages'].join(' ')}`
            puts `ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key`
            puts `ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key`
            puts `sed -ri 's/^#?UsePAM .*/UsePAM no/' /etc/ssh/sshd_config`
          else
            # TODO add more platform steps here
            raise "Platform #{host['platform']} not yet supported on LXC"
          end

          # Get root login working
          puts `sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config`
          puts `sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config`
          puts `echo root:#{root_password} | chpasswd`

          # Run any extra commands in container
          if host.has_key?('extra_commands')
            @logger.notify "Running extra_commands on #{host}"
            host['extra_commands'].each do |extra_command|
              puts `#{extra_command}`
            end
          end
          STDOUT.flush
        end

        host['lxc_container'] = container
        ip = container.ip_addresses.join(",")

        forward_ssh_agent = @options[:forward_ssh_agent] || false

        # Update host metadata
        host['ip']  = ip
        host['port'] = 22
        host['ssh']  = {
          :password => root_password,
          :forward_agent => forward_ssh_agent,
          :port => 22,
        }
      end
      hack_etc_hosts @hosts, @options
      nil
    end

    # Cleanup all earlier provisioned LXC containers
    #
    # @return [void]
    def cleanup
      @logger.notify "Cleaning up LXC containers"

      @hosts.each do | host |
        if container = host['lxc_container']
          @logger.debug("Stopping #{host}")
          begin
            container.stop
            container.wait("stopped", 60)
          rescue Exception => e
            @logger.warn("Failed to stop #{host}: #{e}")
          end

          if host[:lxc_preserve_container] == true
            @logger.debug("Not deleting #{host}")
          else
            @logger.debug("Deleting #{host}")
            begin
              container.destroy
            rescue Exception => e
              @logger.warn("Failed to delete #{host}: #{e}")
            end
          end
        end
      end
      nil
    end

  end
end
