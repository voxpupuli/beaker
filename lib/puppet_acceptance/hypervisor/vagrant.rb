module PuppetAcceptance 
  class Vagrant < PuppetAcceptance::Hypervisor

    # Return a random mac address
    #
    # @return [String] a random mac address
    def randmac
      "080027" + (1..3).map{"%0.2X"%rand(256)}.join
    end

    def initialize(vagrant_hosts, options, config)
      require 'tempfile'
      @options = options
      @config = config
      @logger = options[:logger]
      @temp_files = []

      #HACK HACK HACK - add checks here to ensure that we have box + box_url
      #generate the VagrantFile
      @vagrant_file = ''
      vagrant_hosts.each do |host|
        @vagrant_file = "Vagrant::Config.run do |c|\n"
        @vagrant_file << "  c.vm.define '#{host.name}' do |v|\n"
        @vagrant_file << "    v.vm.host_name = '#{host.name}'\n"
        @vagrant_file << "    v.vm.box = '#{host['box']}'\n"
        @vagrant_file << "    v.vm.box_url = '#{host['box_url']}'\n" unless host['box_url'].nil?
        @vagrant_file << "    v.vm.base_mac = '#{randmac}'\n"
        @vagrant_file << "  end\n"
        @logger.debug "created Vagrantfile for VagrantHost #{host.name}"
      end
      @vagrant_file << "end\n"
      f = File.open("Vagrantfile", 'w') 
      f.write(@vagrant_file)
      f.close()
      system("vagrant up")
      @logger.debug "construct listing of ssh-config per vagrant box name"
      vagrant_hosts.each do |host|
        f = Tempfile.new("#{host.name}")
        config = `vagrant ssh-config #{host.name}`
        f.write(config)
        f.rewind
        host['ssh'] = {:config => f.path()}
        host['user'] = 'vagrant'
        @temp_files << f
      end
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
