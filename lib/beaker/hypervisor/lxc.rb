module Beaker
  class Lxc < Beaker::Hypervisor

    # LXC Hypervisor 
    def initialize(hosts, options)
      require 'lxc'

      @options = options
      @logger  = options[:logger]
      @hosts   = hosts
    end

    # Default root password
    def root_password
      'root'
    end

    require 'shellwords'

    # To run bash command, default ruby gives sh
    def bash(command)
      escaped_command = Shellwords.escape(command)
      system "bash -c #{escaped_command}"
    end

    #  Provision the lxc container
    def provision
      @hosts.each do | host |

        @logger.notify "Provisioning lxc cotainer #{host}"
        container = LXC::Container.new(host)

        template = host['template']
        arch = host['arch'] || "amd64"
       
        # Get template from config and divide it into image and release tag.
        if match = template.match(/(.*):(.*)/)
          image = match.captures[0]
          release = match.captures[1]
        end

        begin
          # Creating the lxc 
          @logger.notify "Creating lxc #{host} with #{template}"
          container.create("download", nil, {}, 0, ["-d", "#{image}", "-r", "#{release}", "-a", "#{arch}"])
        rescue Exception => e
          @logger.error "lxc containter with name #{host} is already present, Please remove it before provisioning."
          exit
        end

        # Config setting, because systemd wont work
        @logger.notify "Setting up config #{host}"
        container.set_config_item('lxc.autodev', '1')
        container.set_config_item('lxc.kmsg', '0')
        # Mount /lib/modules because lxc centos6 fail, with firewall/iptables error on puppet runs
        # But keeping it under all the lxc
        # under lxc, we need the /lib/modules to be created first
        if release =~ /6/
          system "mkdir -p /var/lib/lxc/#{host}/rootfs/lib/modules" 
          container.set_config_item('lxc.mount.entry', "/lib/modules /var/lib/lxc/#{host}/rootfs/lib/modules none bind 0 0")
        end
    
        # Save the config file
        container.save_config

        # Starting the lxc
        @logger.notify "Starting Lxc #{host}"
        container.start

        sleep 30
        if container.running?
          # Run this command on the newly created lxc
          @logger.notify "Attaching Lxc to #{host}"
          container.attach(:wait => true) do
            bash("echo 'nameserver 8.8.8.8' > /etc/resolv.conf")
            case host['platform']
            when /ubuntu/, /debian/
              puts `apt-key update`
              puts `apt-get update`
              puts `apt-get install --force-yes -y wget apt-utils openssh-server openssh-client #{Beaker::HostPrebuiltSteps::DEBIAN_PACKAGES.join(' ')}`
              puts `sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config`
              puts `sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config`
              puts `echo root:#{root_password} | chpasswd`
              if image =~ /ubuntu/
                puts `restart ssh`
              end
              if image =~ /debian/
                puts `/etc/init.d/ssh restart`
              end
            when /^el-/, /centos/, /fedora/, /redhat/, /eos/
              # HACK to fix lxc issue
              if release =~  /7/
                # /run needs to be fix for centos7 lxc
                system "cp -fr /var/run/* /run/ && rm -frv /var/run >/dev/null && ln -s /run /var/run"
              end
              bash("pgrep arping | xargs kill -9")
              bash("sleep 5 && /sbin/dhclient -H #{host} -1 -q -lf /var/lib/dhclient/dhclient-eth0.leases -pf /var/run/dhclient-eth0.pid eth0")
              bash("yum clean all")
              bash("yum install -y sudo initscripts openssh-server openssh-clients shadow-utils #{Beaker::HostPrebuiltSteps::UNIX_PACKAGES.join(' ')}")
              bash("echo root:#{root_password} | /usr/sbin/chpasswd")
              bash("service sshd start")
            when /opensuse/, /sles/
              puts `zypper -n in openssh #{Beaker::HostPrebuiltSteps::SLES_PACKAGES.join(' ')}`
              puts `ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key`
              puts `ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key`
              puts `sed -ri 's/^#?UsePAM .*/UsePAM no/' /etc/ssh/sshd_config`
              puts `echo root:#{root_password} | chpasswd`
            else
              # TODO add more platform steps here
              raise "platform #{host['platform']} not yet supported on lxc"
            end
          end
        end

        host['lxc_container'] = container
        # somehow this is not working in cron	
        sleep 30	
        ip = container.ip_addresses.join(",")

        @logger.notify "Adding hostname #{host} in /etc/hosts"
        system "echo \"#{ip}    #{host}\" >> /etc/hosts"

        # Update host metadata
        host['ip']  = ip
      
        # Check whether password is passed or not under ssh hash
        if ! options[:ssh].has_key?(:password)
          ssh_password = { :password => root_password }
          # Append the hash with default "root:root" password
          host['ssh'].merge!(ssh_password)
        end
        hack_etc_hosts @hosts, @options
      end
    end

    # Remove the lxc after the test.
    def cleanup
      @logger.notify "Cleaning up Lxc Container"
    
      @hosts.each do | host |
        if container = host['lxc_container']
          @logger.debug("stop container #{host}")
          begin
            ip = container.ip_addresses.join(",")
            # If IP is empty it was deleting the /etc/hosts file.
            # So checking first if IP is available or not
            if !ip.empty?
              @logger.notify "Deleting hostname #{host} in /etc/host"
              system "sed -i '/^#{ip}/d' /etc/hosts"
            else
              @logger.notify "IP address not found, skipping to delete hostname from /etc/hosts file"
            end
            # Stop the container
            container.stop
            sleep 2
          rescue Exception => e
            @logger.warn("stop of container #{host} failed: #{e}")
          end
          @logger.debug("delete container #{host}")
          begin
            container.destroy
          rescue Exception => e
            @logger.warn("deletion of container #{host} failed: #{e}")
          end
        end
      end
    end

  end
end
