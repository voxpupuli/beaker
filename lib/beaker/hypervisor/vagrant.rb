require 'open3'

module Beaker
  class Vagrant < Beaker::Hypervisor

    # Return a random mac address
    #
    # @return [String] a random mac address
    def randmac
      "080027" + (1..3).map{"%0.2X"%rand(256)}.join
    end

    def rand_chunk
      (2 + rand(252)).to_s #don't want a 0, 1, or a 255
    end

    def randip
      "10.255.#{rand_chunk}.#{rand_chunk}"
    end

    def make_vfile hosts, options = {}
      #HACK HACK HACK - add checks here to ensure that we have box + box_url
      #generate the VagrantFile
      v_file = "Vagrant.configure(\"2\") do |c|\n"
      v_file << "  c.ssh.forward_agent = true\n" if options[:forward_ssh_agent] == true
      hosts.each do |host|
        host['ip'] ||= randip #use the existing ip, otherwise default to a random ip
        v_file << "  c.vm.define '#{host.name}' do |v|\n"
        v_file << "    v.vm.hostname = '#{host.name}'\n"
        v_file << "    v.vm.box = '#{host['box']}'\n"
        v_file << "    v.vm.box_url = '#{host['box_url']}'\n" unless host['box_url'].nil?
        v_file << "    v.vm.box_version = '#{host['box_version']}'\n" unless host['box_version'].nil?
        v_file << "    v.vm.box_check_update = '#{host['box_check_update'] ||= 'true'}'\n"
        v_file << "    v.vm.network :private_network, ip: \"#{host['ip'].to_s}\", :netmask => \"#{host['netmask'] ||= "255.255.0.0"}\", :mac => \"#{randmac}\"\n"

        if /windows/i.match(host['platform'])
          v_file << "    v.vm.network :forwarded_port, guest: 3389, host: 3389\n"
          v_file << "    v.vm.network :forwarded_port, guest: 5985, host: 5985, id: 'winrm', auto_correct: true\n"
          v_file << "    v.vm.guest = :windows"
        end

        v_file << self.class.provider_vfile_section(host, options)

        v_file << "  end\n"
        @logger.debug "created Vagrantfile for VagrantHost #{host.name}"
      end
      v_file << "end\n"
      File.open(@vagrant_file, 'w') do |f|
        f.write(v_file)
      end
    end

    def self.provider_vfile_section host, options
      # Backwards compatibility; default to virtualbox
      Beaker::VagrantVirtualbox.provider_vfile_section(host, options)
    end

    def set_ssh_config host, user
        f = Tempfile.new("#{host.name}")
        ssh_config = Dir.chdir(@vagrant_path) do
          stdin, stdout, stderr, wait_thr = Open3.popen3('vagrant', 'ssh-config', host.name)
          if not wait_thr.value.success?
            raise "Failed to 'vagrant ssh-config' for #{host.name}"
          end
          stdout.read
        end
        #replace hostname with ip
        ssh_config = ssh_config.gsub(/Host #{host.name}/, "Host #{host['ip']}") unless not host['ip']
        if host['platform'] =~ /windows/
          ssh_config = ssh_config.gsub(/127\.0\.0\.1/, host['ip']) unless not host['ip']
        end
        #set the user
        ssh_config = ssh_config.gsub(/User vagrant/, "User #{user}")
        f.write(ssh_config)
        f.rewind
        host['ssh'] = {:config => f.path()}
        host['user'] = user
        @temp_files << f
    end

    def get_ip_from_vagrant_file(hostname)
      ip = ''
      if File.file?(@vagrant_file) #we should have a vagrant file available to us for reading
        f = File.read(@vagrant_file)
        m = /#{hostname}.*?ip:\s*('|")\s*([^'"]+)('|")/m.match(f)
        if m
          ip = m[2]
          @logger.debug("Determined existing vagrant box #{hostname} ip to be: #{ip} ")
        else
          raise("Unable to determine ip for vagrant box #{hostname}")
        end
      else
        raise("No vagrant file found (should be located at #{@vagrant_file})")
      end
      ip
    end

    def initialize(vagrant_hosts, options)
      require 'tempfile'
      @options = options
      @logger = options[:logger]
      @temp_files = []
      @hosts = vagrant_hosts
      @vagrant_path = File.expand_path(File.join(File.basename(__FILE__), '..', '.vagrant', 'beaker_vagrant_files', File.basename(options[:hosts_file])))
      FileUtils.mkdir_p(@vagrant_path)
      @vagrant_file = File.expand_path(File.join(@vagrant_path, "Vagrantfile"))

    end

    def provision(provider = nil)
      if !@options[:provision] and !File.file?(@vagrant_file)
        raise "Beaker is configured with provision = false but no vagrant file was found at #{@vagrant_file}. You need to enable provision"
      end
      if @options[:provision]
        #setting up new vagrant hosts
        #make sure that any old boxes are dead dead dead
        vagrant_cmd("destroy --force") if File.file?(@vagrant_file)

        make_vfile @hosts, @options

        vagrant_cmd("up#{" --provider #{provider}" if provider}")
      else #set host ip of already up boxes
        @hosts.each do |host|
          host[:ip] = get_ip_from_vagrant_file(host.name)
        end
      end

      @logger.debug "configure vagrant boxes (set ssh-config, switch to root user, hack etc/hosts)"
      @hosts.each do |host|
        default_user = host['user']

        set_ssh_config host, 'vagrant'

        #copy vagrant's keys to roots home dir, to allow for login as root
        copy_ssh_to_root host, @options
        #ensure that root login is enabled for this host
        enable_root_login host, @options
        #shut down connection, will reconnect on next exec
        host.close

        set_ssh_config host, default_user
      end

      hack_etc_hosts @hosts, @options

    end

    def cleanup
      @logger.debug "removing temporory ssh-config files per-vagrant box"
      @temp_files.each do |f|
        f.close()
      end
      @logger.notify "Destroying vagrant boxes"
      vagrant_cmd("destroy --force")
      FileUtils.rm_rf(@vagrant_path)
    end

    def vagrant_cmd(args)
      Dir.chdir(@vagrant_path) do
        exit_status = 1
        Open3.popen3("vagrant #{args}") {|stdin, stdout, stderr, wait_thr|
          while line = stdout.gets
            @logger.info(line)
          end
          if not wait_thr.value.success?
            raise "Failed to exec 'vagrant #{args}'. Error was #{stderr.read}"
          end
          exit_status = wait_thr.value
        }
        if exit_status != 0
          raise "Failed to execute vagrant_cmd ( #{args} ). Error was #{stderr.read}"
        end
      end
    end

  end
end
