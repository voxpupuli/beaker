module Beaker
  class Docker < Beaker::Hypervisor

    # Docker hypvervisor initializtion
    # Env variables supported:
    # DOCKER_REGISTRY: Docker registry URL
    # DOCKER_HOST: Remote docker host
    # DOCKER_BUILDARGS: Docker buildargs map
    # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
    #                            or a role (String or Symbol) that identifies one or more hosts.
    # @param [Hash{Symbol=>String}] options Options to pass on to the hypervisor
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
        raise "Docker instance not connectable.\nError was: #{e}\nCheck your DOCKER_HOST variable has been set\nIf you are on OSX or Windows, you might not have Docker Machine setup correctly: https://docs.docker.com/machine/\n"
      end

      # Pass on all the logging from docker-api to the beaker logger instance
      ::Docker.logger = @logger

      # Find out what kind of remote instance we are talking against
      if ::Docker.version['Version'] =~ /swarm/
        @docker_type = 'swarm'
        unless ENV['DOCKER_REGISTRY']
          raise "Using Swarm with beaker requires a private registry. Please setup the private registry and set the 'DOCKER_REGISTRY' env var"
        else
          @registry = ENV['DOCKER_REGISTRY']
        end
      else
        @docker_type = 'docker'
      end

    end

    def provision
      @logger.notify "Provisioning docker"

      @hosts.each do |host|
        @logger.notify "provisioning #{host.name}"

        @logger.debug("Creating image")
        image = ::Docker::Image.build(dockerfile_for(host), {
           :rm => true, :buildargs => buildargs_for(host)
        })

        if @docker_type == 'swarm'
          image_name = "#{@registry}/beaker/#{image.id}"
          ret = ::Docker::Image.search(:term => image_name)
          if ret.first.nil?
            @logger.debug("Image does not exist on registry. Pushing.")
            image.tag({:repo => image_name, :force => true})
            image.push
          end
        else
          image_name = image.id
        end

        container_opts = {
          'Image' => image_name,
          'Hostname' => host.name,
        }
        container = find_container(host)

        # If the specified container exists, then use it rather creating a new one
        if container.nil?
          unless host['mount_folders'].nil?
            container_opts['HostConfig'] ||= {}
            container_opts['HostConfig']['Binds'] = host['mount_folders'].values.map do |mount|
              a = [ File.expand_path(mount['host_path']), mount['container_path'] ]
              a << mount['opts'] if mount.has_key?('opts')
              a.join(':')
            end
          end

          if @options[:provision]
            if host['docker_container_name']
              container_opts['name'] = host['docker_container_name']
            end

            @logger.debug("Creating container from image #{image_name}")
            container = ::Docker::Container.create(container_opts)
          end
        end

        if container.nil?
          raise RuntimeError, 'Cannot continue because no existing container ' +
                              'could be found and provisioning is disabled.'
        end

        fix_ssh(container) if @options[:provision] == false

        @logger.debug("Starting container #{container.id}")
        container.start({"PublishAllPorts" => true, "Privileged" => true})

        # Find out where the ssh port is from the container
        # When running on swarm DOCKER_HOST points to the swarm manager so we have to get the
        # IP of the swarm slave via the container data
        # When we are talking to a normal docker instance DOCKER_HOST can point to a remote docker instance.

        # Talking against a remote docker host which is a normal docker host
        if @docker_type == 'docker' && ENV['DOCKER_HOST']
          ip = URI.parse(ENV['DOCKER_HOST']).host
        else
          # Swarm or local docker host
          ip = container.json["NetworkSettings"]["Ports"]["22/tcp"][0]["HostIp"]
        end

        @logger.info("Using docker server at #{ip}")
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
        host['vm_ip'] = container.json["NetworkSettings"]["IPAddress"].to_s

      end

      hack_etc_hosts @hosts, @options

    end

    def cleanup
      @logger.notify "Cleaning up docker"
      @hosts.each do |host|
        if container = host['docker_container']
          @logger.debug("stop container #{container.id}")
          begin
            container.kill
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
          rescue ::Docker::Error::DockerError => e
            @logger.warn("deletion of image #{image.id} caused internal Docker error: #{e.message}")
          end
        end
      end
    end

    private

    def root_password
      'root'
    end

    def buildargs_for(host)
      docker_buildargs = {}
      docker_buildargs_env = ENV['DOCKER_BUILDARGS']
      if docker_buildargs_env != nil
        docker_buildargs_env.split(/ +|\t+/).each do |arg|
          key,value=arg.split(/=/)
          if key
            docker_buildargs[key]=value
          else
            @logger.warn("DOCKER_BUILDARGS environment variable appears invalid, no key found for value #{value}" )
          end
        end
      end
      if docker_buildargs.empty?
        buildargs = host['docker_buildargs'] || {}
      else
        buildargs = docker_buildargs
      end
      @logger.debug("Docker build buildargs: #{buildargs}")
      JSON.generate(buildargs)
    end

    def dockerfile_for(host)
      if host['dockerfile'] then
        @logger.debug("attempting to load user Dockerfile from #{host['dockerfile']}")
        if File.exist?(host['dockerfile']) then
          dockerfile = File.read(host['dockerfile'])
        else
          raise "requested Dockerfile #{host['dockerfile']} does not exist"
        end 
      else 
        raise("Docker image undefined!") if (host['image']||= nil).to_s.empty?

        # specify base image
        dockerfile = <<-EOF
          FROM #{host['image']}
          ENV container docker
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
        when /fedora-(2[2-9])/
          dockerfile += <<-EOF
            RUN dnf clean all
            RUN dnf install -y sudo openssh-server openssh-clients #{Beaker::HostPrebuiltSteps::UNIX_PACKAGES.join(' ')}
            RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key
            RUN ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key
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
        # Also, disable reverse DNS lookups to prevent every. single. ssh
        # operation taking 30 seconds while the lookup times out.
        dockerfile += <<-EOF
          RUN sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
          RUN sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
          RUN sed -ri 's/^#?UseDNS .*/UseDNS no/' /etc/ssh/sshd_config
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

      end

      @logger.debug("Dockerfile is #{dockerfile}")
      return dockerfile
    end

    # a puppet run may have changed the ssh config which would
    # keep us out of the container.  This is a best effort to fix it.
    def fix_ssh(container)
      @logger.debug("Fixing ssh on container #{container.id}")
      container.exec(['sed','-ri',
                      's/^#?PermitRootLogin .*/PermitRootLogin yes/',
                      '/etc/ssh/sshd_config'])
      container.exec(['sed','-ri',
                      's/^#?PasswordAuthentication .*/PasswordAuthentication yes/',
                      '/etc/ssh/sshd_config'])
      container.exec(['sed','-ri',
                      's/^#?UseDNS .*/UseDNS no/',
                      '/etc/ssh/sshd_config'])
      container.exec(%w(service ssh restart))
    end


    # return the existing container if we're not provisioning
    # and docker_container_name is set
    def find_container(host)
      return nil if host['docker_container_name'].nil? || @options[:provision]
      @logger.debug("Looking for an existing container called #{host['docker_container_name']}")

      ::Docker::Container.all.select do |c|
        c.info['Names'].include? "/#{host['docker_container_name']}"
      end.first
    end

  end
end
