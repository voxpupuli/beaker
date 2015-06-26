module Beaker
  class Lxc < Beaker::Hypervisor

  def initialize(hosts, options)
    require 'lxc'

    @options = options
    @logger  = options[:logger]
    @hosts   = hosts
  end

  def root_password
    'root'
  end

  def provision
   @hosts.each do | host |

      @logger.notify "Provisioning lxc"
      container = LXC::Container.new(host)

      template = host['template']
      arch = host['arch'] || "amd64"
      
      if match = template.match(/(.*):(.*)/)
        image = match.captures[0]
        release = match.captures[1]
      end

      @logger.notify "Creating lxc #{host} with #{template}"
      container.create("download", nil, {}, 0, ["-d", "#{image}", "-r", "#{release}", "-a", "#{arch}"])

      @logger.notify "Setting up config #{host}"
      container.set_config_item('lxc.cap.drop', '')
      container.save_config

      @logger.notify "Starting Lxc #{host}"
      container.start

      @logger.notify "Attaching Lxc to #{host}"
        container.attach(:wait => true) do
          case host['platform']
          when /ubuntu/, /debian/
            puts `apt-get update`
            puts `apt-get install -y openssh-server openssh-client #{Beaker::HostPrebuiltSteps::DEBIAN_PACKAGES.join(' ')}`
          when /^el-/, /centos/, /fedora/, /redhat/, /eos/
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

          puts `sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config`
          puts `sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config`
          puts `echo root:#{root_password} | chpasswd`
      end

      host['lxc_container'] = container
      ip = container.ip_addresses.join(",")
      forward_ssh_agent = false

      @logger.notify "Adding hostname #{host} in /etc/hosts"
      system "echo -e '#{ip}\t#{host}' >> /etc/hosts"

      # Update host metadata
      host['ip']  = ip
      host['ssh']  = {
        :password => root_password,
        :forward_agent => forward_ssh_agent,
      }
    end
  end

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
        rescue Excon::Errors::ClientError => e
          @logger.warn("stop of container #{host} failed: #{e.response.body}")
        end
        @logger.debug("delete container #{host}")
        begin
          container.destroy
        rescue Excon::Errors::ClientError => e
          @logger.warn("deletion of container #{host} failed: #{e.response.body}")
        end
      end
    end
  end

end
end
