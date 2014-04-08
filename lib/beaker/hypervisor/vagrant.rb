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
      hosts.each do |host|
        host['ip'] ||= randip #use the existing ip, otherwise default to a random ip
        v_file << "  c.vm.define '#{host.name}' do |v|\n"
        v_file << "    v.vm.hostname = '#{host.name}'\n"
        v_file << "    v.vm.box = '#{host['box']}'\n"
        v_file << "    v.vm.box_url = '#{host['box_url']}'\n" unless host['box_url'].nil?
        v_file << "    v.vm.base_mac = '#{randmac}'\n"
        v_file << "    v.vm.network :private_network, ip: \"#{host['ip'].to_s}\", :netmask => \"#{host['netmask'] ||= "255.255.0.0"}\"\n"
        v_file << "  end\n"
        @logger.debug "created Vagrantfile for VagrantHost #{host.name}"
      end
      v_file << "  c.vm.provider :virtualbox do |vb|\n"
      v_file << "    vb.customize [\"modifyvm\", :id, \"--memory\", \"#{options['vagrant_memsize'] ||= '1024'}\"]\n"
      v_file << "  end\n"
      v_file << "end\n"
      File.open(@vagrant_file, 'w') do |f|
        f.write(v_file)
      end
    end

    def set_ssh_config host, user
        f = Tempfile.new("#{host.name}")
        ssh_config = Dir.chdir(@vagrant_path) do
          result = `vagrant ssh-config #{host.name}`
          if $?.to_i != 0
            raise "Failed to vagrant ssh-config for #{host.name}"
          end
          result
        end
        #replace hostname with ip
        ssh_config = ssh_config.gsub(/#{host.name}/, host['ip']) unless not host['ip']
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

    def provision
      if !@options[:provision] and !File.file?(@vagrant_file)
        raise "Beaker is configured with provision = false but no vagrant file was found at #{@vagrant_file}. You need to enable provision"
      end
      if @options[:provision]
        #setting up new vagrant hosts
        #make sure that any old boxes are dead dead dead
        vagrant_cmd("destroy --force") if File.file?(@vagrant_file)

        make_vfile @hosts, @options

        vagrant_cmd("up")
      else #set host ip of already up boxes
        @hosts.each do |host|
          host[:ip] = get_ip_from_vagrant_file(host.name)
        end
      end

      @logger.debug "configure vagrant boxes (set ssh-config, switch to root user, hack etc/hosts)"
      @hosts.each do |host|
        default_user = host['user']
      
        set_ssh_config host, 'vagrant'

        copy_ssh_to_root host, @options
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
        result = `vagrant #{args} 2>&1`
        result.each_line do |line|
          @logger.debug(line)
        end
        if $?.to_i != 0
          raise "Failed to exec 'vagrant #{args}'"
        end
      end
    end

  end
end
