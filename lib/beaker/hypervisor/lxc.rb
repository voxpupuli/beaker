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
      container.set_config_item('lxc.cap.drop', '')
      container.save_config

      # Starting the lxc
      @logger.notify "Starting Lxc #{host}"
      container.start

      # Run this command on the newly created lxc
      @logger.notify "Attaching Lxc to #{host}"
        container.attach(:wait => true) do
          case host['platform']
          when /ubuntu/, /debian/
            puts `apt-get update`
            puts `apt-get install -y openssh-server openssh-client #{Beaker::HostPrebuiltSteps::DEBIAN_PACKAGES.join(' ')}`
          when /^el-/, /centos/, /fedora/, /redhat/, /eos/
            # HACK to fix the /run 
            if release =~  /7/
              puts `cp -fr /var/run/* /run/ && rm -frv /var/run >/dev/null && ln -s /run /var/run`
            end
            puts `ifup eth0`
            puts `yum clean all`
            puts `yum install -y sudo initscripts openssh-server openssh-clients #{Beaker::HostPrebuiltSteps::UNIX_PACKAGES.join(' ')}`
            puts `service sshd start`
          when /opensuse/, /sles/
            puts `zypper -n in openssh #{Beaker::HostPrebuiltSteps::SLES_PACKAGES.join(' ')}`
            puts `ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key`
            puts `ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key`
            puts `sed -ri 's/^#?UsePAM .*/UsePAM no/' /etc/ssh/sshd_config`
          else
            # TODO add more platform steps here
            raise "platform #{host['platform']} not yet supported on docker"
          end
      
          # Get root login working
          puts `sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config`
          puts `sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config`
          puts `echo root:#{root_password} | chpasswd`
      end

      host['lxc_container'] = container
      ip = container.ip_addresses.join(",")
      forward_ssh_agent = false

      @logger.notify "Adding hostname #{host} in /etc/hosts"
      system "echo '#{ip}    #{host}' >> /etc/hosts"

      # Update host metadata
      host['ip']  = ip
      host['ssh']  = {
        :password => root_password,
        :forward_agent => forward_ssh_agent,
      }
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
          @logger.notify "Deleting hostname #{host} in /etc/host"
          system "sed -i '/^#{ip}/d' /etc/hosts"
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
