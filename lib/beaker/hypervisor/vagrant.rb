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

    def make_vfile hosts
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
        v_file << "    v.vm.network :private_network, ip: \"#{host['ip'].to_s}\", :netmask => \"255.255.0.0\"\n"
        v_file << "  end\n"
        @logger.debug "created Vagrantfile for VagrantHost #{host.name}"
      end
      v_file << "  c.vm.provider :virtualbox do |vb|\n"
      v_file << "    vb.customize [\"modifyvm\", :id, \"--memory\", \"1024\"]\n"
      v_file << "  end\n"
      v_file << "end\n"
      File.open(@vagrant_file, 'w') do |f|
        f.write(v_file)
      end
    end

    def hack_etc_hosts hosts
      etc_hosts = "127.0.0.1\tlocalhost localhost.localdomain\n"
      hosts.each do |host|
        etc_hosts += "#{host['ip'].to_s}\t#{host.name}\n"
      end
      hosts.each do |host|
        set_etc_hosts(host, etc_hosts)
      end
    end

    def copy_ssh_to_root host
      #make is possible to log in as root by copying the ssh dir to root's account
      @logger.debug "Give root a copy of vagrant's keys"
      if host['platform'] =~ /windows/
        host.exec(Command.new('sudo su -c "cp -r .ssh /home/Administrator/."'))
      else
        host.exec(Command.new('sudo su -c "cp -r .ssh /root/."'))
      end
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
        ssh_config = ssh_config.gsub(/#{host.name}/, host['ip']) unless not host['ip']
        #set the user
        ssh_config = ssh_config.gsub(/User vagrant/, "User #{user}")
        f.write(ssh_config)
        f.rewind
        host['ssh'] = {:config => f.path()}
        host['user'] = user
        @temp_files << f
    end

    def initialize(vagrant_hosts, options)
      require 'tempfile'
      @options = options
      @logger = options[:logger]
      @temp_files = []
      @vagrant_hosts = vagrant_hosts
      @vagrant_path = File.expand_path(File.join(File.basename(__FILE__), '..', '.vagrant', 'beaker_vagrant_files', File.basename(options[:hosts_file])))
      FileUtils.mkdir_p(@vagrant_path)
      @vagrant_file = File.expand_path(File.join(@vagrant_path, "Vagrantfile"))

    end

    def provision
      if @options[:provision]
        #setting up new vagrant hosts
        #make sure that any old boxes are dead dead dead
        vagrant_cmd("destroy --force") if File.file?(@vagrant_file)

        make_vfile @vagrant_hosts

        vagrant_cmd("up")
      end
      @logger.debug "configure vagrant boxes (set ssh-config, switch to root user, hack etc/hosts)"
      @vagrant_hosts.each do |host|
        default_user = host['user']
      
        set_ssh_config host, 'vagrant'

        copy_ssh_to_root host
        #shut down connection, will reconnect on next exec
        host.close

        set_ssh_config host, default_user
      end

      hack_etc_hosts @vagrant_hosts

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
            @logger.debug(line)
          end
          if not wait_thr.value.success?
            raise "Failed to exec 'vagrant #{args}'"
          end
          exit_status = wait_thr.value 
        }
        if exit_status != 0
          raise "Failed to execute vagrant_cmd ( #{args} )"
        end
      end
    end

  end
end
