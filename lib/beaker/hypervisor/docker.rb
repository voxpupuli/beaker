module Beaker
  class Docker < Beaker::Hypervisor

    def initialize(hosts, options)
      require 'docker'
      @options = options
      @logger = options[:logger]
      @hosts = hosts

      # increase the http timeouts as provisioning images can be slow
      default_docker_options = { :write_timeout => 300, :read_timeout => 300 }.merge(::Docker.options || {})
      # Merge docker options from the entry in hosts file
      ::Docker.options = default_docker_options.merge(@options[:docker_options] || {})
      # assert that the docker-api gem can talk to your docker
      # enpoint.  Will raise if there is a version mismatch
      begin
        ::Docker.validate_version!
      rescue Excon::Errors::SocketError => e
        raise "Docker instance not found.\nif you are on OSX, you might not have Boot2Docker setup correctly\nCheck your DOCKER_HOST variable has been set"
      end

      # Pass on all the logging from docker-api to the beaker logger instance
      ::Docker.logger = @logger
    end

    def provision
      @logger.notify "Provisioning docker"

      @hosts.each do |host|
        @logger.notify "provisioning #{host.name}"

        @logger.debug("Creating image")
        image = ::Docker::Image.build(dockerfile_for(host), { :rm => true })

        @logger.debug("Creating container from image #{image.id}")
        container = ::Docker::Container.create({
          'Image' => image.id,
          'Hostname' => host.name,
        })

        @logger.debug("Starting container #{container.id}")
        container.start({"PublishAllPorts" => true, "Privileged" => true})

        # Find out where the ssh port is from the container
        if ENV['DOCKER_HOST']
          ip = URI.parse(ENV['DOCKER_HOST']).host
          @logger.info("Using docker server at #{ip}")
        else
          ip = container.json["NetworkSettings"]["Ports"]["22/tcp"][0]["HostIp"]
        end
        port = container.json["NetworkSettings"]["Ports"]["22/tcp"][0]["HostPort"]

        forward_ssh_agent = @options[:forward_ssh_agent] || false

        # Update host metadata
        host['ip']  = ip
        host['port'] = port
        host['ssh']  = {
          :password => root_password,
          :port => port,
          :forward_agent => forward_ssh_agent,
        }

        @logger.debug("node available as  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@#{ip} -p #{port}")
        host['docker_container'] = container
        host['docker_image'] = image
      end

      hack_etc_hosts @hosts, @options

    end

    def cleanup
      @logger.notify "Cleaning up docker"
      @hosts.each do |host|
        if container = host['docker_container']
          @logger.debug("stop container #{container.id}")
          begin
            container.stop
            sleep 2 # avoid a race condition where the root FS can't unmount
          rescue Excon::Errors::ClientError => e
            @logger.warn("stop of container #{container.id} failed: #{e.response.body}")
          end
          @logger.debug("delete container #{container.id}")
          begin
            container.delete
          rescue Excon::Errors::ClientError => e
            @logger.warn("deletion of container #{container.id} failed: #{e.response.body}")
          end
        end

        # Do not remove the image if docker_reserve_image is set to true, otherwise remove it
        if image = (host['docker_preserve_image'] ? nil : host['docker_image'])
          @logger.debug("delete image #{image.id}")
          begin
            image.delete
          rescue Excon::Errors::ClientError => e
            @logger.warn("deletion of image #{image.id} failed: #{e.response.body}")
          end
        end
      end
    end

    private

    def root_password
      'root'
    end

    def dockerfile_for(host)

      # Warn if image is not define, empty or nil
      @logger.error("Docker image undefined!") if (host['image']||= nil).to_s.empty?

      # specify base image
      dockerfile = <<-EOF
        FROM #{host['image']}
      EOF

      # additional options to specify to the sshd
      # may vary by platform
      sshd_options = ''

      # add platform-specific actions
      service_name = "sshd"
      case host['platform']
      when /ubuntu/, /debian/
        service_name = "ssh"
        dockerfile += <<-EOF
          RUN apt-get update
          RUN apt-get install -y openssh-server openssh-client #{Beaker::HostPrebuiltSteps::DEBIAN_PACKAGES.join(' ')}
        EOF
        when  /cumulus/
          dockerfile += <<-EOF
          RUN apt-get update
          RUN apt-get install -y openssh-server openssh-client #{Beaker::HostPrebuiltSteps::CUMULUS_PACKAGES.join(' ')}
        EOF
      when /^el-/, /centos/, /fedora/, /redhat/, /eos/
        dockerfile += <<-EOF
          RUN yum clean all
          RUN yum install -y sudo openssh-server openssh-clients #{Beaker::HostPrebuiltSteps::UNIX_PACKAGES.join(' ')}
          RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key
          RUN ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key
        EOF
      when /opensuse/, /sles/
        dockerfile += <<-EOF
          RUN zypper -n in openssh #{Beaker::HostPrebuiltSteps::SLES_PACKAGES.join(' ')}
          RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key
          RUN ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key
          RUN sed -ri 's/^#?UsePAM .*/UsePAM no/' /etc/ssh/sshd_config
        EOF
      else
        # TODO add more platform steps here
        raise "platform #{host['platform']} not yet supported on docker"
      end

      # Make sshd directory, set root password
      dockerfile += <<-EOF
        RUN mkdir -p /var/run/sshd
        RUN echo root:#{root_password} | chpasswd
      EOF

      # Configure sshd service to allowroot login using password
      dockerfile += <<-EOF
        RUN sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
        RUN sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
      EOF


      # Any extra commands specified for the host
      dockerfile += (host['docker_image_commands'] || []).map { |command|
        "RUN #{command}\n"
      }.join('')

      # Override image entrypoint
      if host['docker_image_entrypoint']
        dockerfile += "ENTRYPOINT #{host['docker_image_entrypoint']}\n"
      end

      # How to start a sshd on port 22.  May be an init for more supervision
      # Ensure that the ssh server can be restarted (done from set_env) and container keeps running
      cmd = host['docker_cmd'] || ["sh","-c","service #{service_name} start ; tail -f /dev/null"]
      dockerfile += <<-EOF
        EXPOSE 22
        CMD #{cmd}
      EOF

      @logger.debug("Dockerfile is #{dockerfile}")
      return dockerfile
    end

  end
end
