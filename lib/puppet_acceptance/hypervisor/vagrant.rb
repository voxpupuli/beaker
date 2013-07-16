module PuppetAcceptance 
  class Vagrant < PuppetAcceptance::Hypervisor

    # Return a random mac address
    #
    # @return [String] a random mac address
    def randmac
      "080027" + (1..3).map{"%0.2X"%rand(256)}.join
    end

    def rand_chunk
      (1 + rand(253)).to_s #don't want a 0 or a 255
    end
    
    def randip
      "192.168.#{rand_chunk}.#{rand_chunk}"
    end

    def make_vfile hosts
      #HACK HACK HACK - add checks here to ensure that we have box + box_url
      #generate the VagrantFile
      vagrant_file = "Vagrant::Config.run do |c|\n"
      hosts.each do |host|
        host['ip'] ||= randip #use the existing ip, otherwise default to a random ip
        vagrant_file << "  c.vm.define '#{host.name}' do |v|\n"
        vagrant_file << "    v.vm.host_name = '#{host.name}'\n"
        vagrant_file << "    v.vm.box = '#{host['box']}'\n"
        vagrant_file << "    v.vm.box_url = '#{host['box_url']}'\n" unless host['box_url'].nil?
        vagrant_file << "    v.vm.base_mac = '#{randmac}'\n"
        vagrant_file << "    v.vm.network :hostonly, \"#{host['ip'].to_s}\"\n"
        vagrant_file << "    v.vm.customize [\"modifyvm\", :id, \"--memory\", \"1024\"]\n"
        vagrant_file << "  end\n"
        @logger.debug "created Vagrantfile for VagrantHost #{host.name}"
      end
      vagrant_file << "end\n"
      f = File.open("Vagrantfile", 'w') 
      f.write(vagrant_file)
      f.close()
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
        ssh_config = `vagrant ssh-config #{host.name}`
        #replace hostname with ip
        ssh_config = ssh_config.gsub(/#{host.name}/, host['ip']) 
        #set the user 
        ssh_config = ssh_config.gsub(/User vagrant/, "User #{user}") 
        f.write(ssh_config)
        f.rewind
        host['ssh'] = {:config => f.path()}
        host['user'] = user
        @temp_files << f
    end

    def initialize(vagrant_hosts, options, config)
      require 'tempfile'
      @options = options
      @config = config['CONFIG'].dup
      @logger = options[:logger]
      @temp_files = []
      @vagrant_hosts = vagrant_hosts

      make_vfile @vagrant_hosts

      #stop anything currently running, that way vagrant up will re-do networking on existing boxes
      system("vagrant halt") 
      system("vagrant up")

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
      system("vagrant destroy --force")
    end

  end
end
