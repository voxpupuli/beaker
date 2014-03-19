require 'docker'
require 'tempfile'
require 'securerandom'

module Beaker
  class DockerHypervisor < Beaker::Hypervisor

    def get_sshd_start_script
      "#!/bin/sh\n"\
        "mkdir /var/run/sshd\n"\
        "$(which sshd) -D\n"
    end

    def image_add_file!(image_in, path, content=nil,source_path=nil,remove=true)

      if not content.nil?
        temp_file = Tempfile.new("image-add-file")
        temp_file.write(content)
        temp_file.flush
        source_path = temp_file.path
      end
        
      image_out = image_in.insert_local('localPath' => source_path, 'outputPath' => path, 'rm' => true)
      
      return image_out

    end

    def image_run!(image_in, cmd, commit=false, remove=false)

      # Run command in container 
      container=image_in.run(cmd)
      retval = container.wait(5)['StatusCode'].to_i
     
      raise "command execution failed: #{cmd}" if retval != 0 and commit 

      # Commit
      image_out = container.commit() if commit

      # Remove container
      container.delete(:force => true)

      # Remove old image
      # TODO find out why not working
      #image_in.remove(:force => true) if remove

      if commit
        return image_out
      else
        return retval
      end
    end



    def get_ssh_config(host)
      user = 'root'

      ssh_config = "Host #{host[:ip]}\n" \
        "    HostName #{host[:ip]}\n" \
        "    IdentityFile #{@ssh_private_key_path}\n" \
        "    User #{user}\n"

      # Write ssh config
      f = Tempfile.new("#{host.name}")
      f.write(ssh_config)
      f.rewind

      @logger.debug("Wrote ssh config for host '#{host.name}' to '#{f.path}'")

      # Set ssh config for beaker
      host['ssh'] = {:config => f.path()}
      host['user'] = user

      # Clean up ssh config
      @temp_files << f
    end

    def create_ssh_keys
      path = File.join('/tmp',SecureRandom.hex)

      @logger.debug "Creating temporary ssh key '#{path}'" 
      ret_val = system( "ssh-keygen -q  -f '#{path}' -t rsa -b 2048 -N ''" )
      if not ret_val
        raise 'Error creating ssh key'
      end

      @ssh_private_key_path = path
      @ssh_public_key_path = "#{path}.pub"

      @temp_files << @ssh_public_key_path
      @temp_files << @ssh_private_key_path

    end

    def initialize(hosts, options)
      @options = options
      @logger = options[:logger]
      @temp_files = []
      @docker_hosts = hosts
      @docker_images = {}
      @docker_images_temp = []
      @docker_containers_temp = [] 
      @ssh_private_key_path = nil
      @ssh_public_key_path = nil

      create_ssh_keys

    end

    def get_modified_image(image_name)
      @logger.debug "Getting docker image #{image_name}"

      # Basic image
      image = Docker::Image.create('fromImage' => image_name)

      # Check if sshd exists
      ssh_found = image_run!(image, 'which sshd')
      if ssh_found != 0
        raise "No sshd command found in image #{image_name}"
      end
      @logger.debug 'Testing image for sshd: found'

      # Create runscript
      image = image_add_file!(image, '/run.sh', get_sshd_start_script)

      # Copy ssh key
      image = image_add_file!(image, '/root/.ssh/authorized_keys', nil, @ssh_public_key_path)

      # Chmod +x 
      image = image_run!(image, 'chmod +x /run.sh', commit=true, remove=true)

      return image
    end

    def get_image(image_name)

      if @docker_images.has_key?(image_name)
        return @docker_images[image_name]
      else
        image = get_modified_image(image_name)
        @docker_images_temp << image
        @docker_images[image_name] = image
        return image
      end 
    end


    def provision
      @logger.debug 'Provisioning docker boxes'
      @docker_hosts.each do |host|

        # Check if container exists
        image = get_image host['docker_image']

        # Run container
        opts = { 
          'Image' => image.id,
          'Hostname' => host,
          'Cmd' => '/run.sh',
        }
        container = Docker::Container.create(opts).tap(&:start!)
        host[:ip] = container.json['NetworkSettings']['IPAddress']
        @logger.debug "Started container '#{host}' on ip='#{host[:ip]}'"

        # Add container to global list
        @docker_containers_temp << container

        # Generate SSH config for containers
        get_ssh_config host

      end
    end


    def cleanup
      
      # Stop & remove containers
      @docker_containers_temp.each do |container|
        @logger.debug "Stop & Remove container: #{container.id}"
        container.stop
        container.delete(:force => true)
      end

      # Remove images
      @docker_images_temp.reverse.each do |image|
        @logger.debug "Remove temporary image: #{image.id}"
        image.remove(:force => true)
      end

      # Remove files
      @temp_files.each do |file|
        if file.is_a?(String)
          @logger.debug "Remove temporary file: #{file}"
          File.delete(file) if file.is_a?(String)
        elsif file.is_a?(File)          
          @logger.debug "Remove temporary file: #{file.path}"
          file.close 
        end
      end
    end
  end
end
