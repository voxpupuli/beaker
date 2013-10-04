require 'spec_helper'

module Beaker
  describe Vagrant do
    let( :logger ) { double( 'logger' ).as_null_object }
    let( :defaults ) { Beaker::Options::OptionsHash.new.merge( { :logger => logger, :hosts_file => 'sample.cfg'} ) }
    let( :options ) { @options ? defaults.merge( @options ) : defaults}

    let( :vagrant ) { Beaker::Vagrant.new( @hosts, options ) }
    let( :vms ) { ['vm1', 'vm2', 'vm3'] }
    let( :snaps )  { ['snapshot1', 'snapshot2', 'snapshot3'] }

    before :each do
      @hosts = make_hosts( vms, snaps )
    end

    def make_host name, snap, platform = 'unix'
      opts = Beaker::Options::OptionsHash.new.merge( { :logger => logger, 'HOSTS' => { name => { 'platform' => platform, :snapshot => snap } } } )
      host = Host.create( name, opts )
      host[:ip] = "ip.address.for.#{name}"
      host[:box] = "#{name}_of_my_box"
      host[:box_url] = "http://address.for.my.box.#{name}"
      host
    end

    def make_hosts names, snaps
      hosts = []
      names.zip(snaps).each do |vm, snap|
        hosts << make_host( vm, snap )
      end
      hosts
    end

    it "can make a Vagranfile for a set of hosts" do
      vagrant.stub( :randmac ).and_return( "0123456789" )
      FileUtils.stub( :mkdir_p ).and_return( true )
      file = mock('file')
      File.stub( :join ).and_return( "filename" )
      File.stub( :expand_path ).and_return( "path/filename" )

      File.should_receive(:open).with("path/filename", "w").and_yield(file)
      file.should_receive(:write).with("Vagrant.configure(\"2\") do |c|\n  c.vm.define 'vm1' do |v|\n    v.vm.hostname = 'vm1'\n    v.vm.box = 'vm1_of_my_box'\n    v.vm.box_url = 'http://address.for.my.box.vm1'\n    v.vm.base_mac = '0123456789'\n    v.vm.network :private_network, ip: \"ip.address.for.vm1\", :netmask => \"255.255.0.0\"\n  end\n  c.vm.define 'vm2' do |v|\n    v.vm.hostname = 'vm2'\n    v.vm.box = 'vm2_of_my_box'\n    v.vm.box_url = 'http://address.for.my.box.vm2'\n    v.vm.base_mac = '0123456789'\n    v.vm.network :private_network, ip: \"ip.address.for.vm2\", :netmask => \"255.255.0.0\"\n  end\n  c.vm.define 'vm3' do |v|\n    v.vm.hostname = 'vm3'\n    v.vm.box = 'vm3_of_my_box'\n    v.vm.box_url = 'http://address.for.my.box.vm3'\n    v.vm.base_mac = '0123456789'\n    v.vm.network :private_network, ip: \"ip.address.for.vm3\", :netmask => \"255.255.0.0\"\n  end\n  c.vm.provider :virtualbox do |vb|\n    vb.customize [\"modifyvm\", :id, \"--memory\", \"1024\"]\n  end\nend\n")

      vagrant.make_vfile( @hosts )
    end

    it "can generate a new /etc/hosts file referencing each host" do

      @hosts.each do |host|
        vagrant.should_receive( :set_etc_hosts ).with( host, "127.0.0.1\tlocalhost localhost.localdomain\nip.address.for.vm1\tvm1\nip.address.for.vm2\tvm2\nip.address.for.vm3\tvm3\n" ).exactly( 1 ).times
      end

      vagrant.hack_etc_hosts( @hosts )

    end

    context "can copy vagrant's key to root .ssh on each host" do

      it "can copy to root on unix" do
        host = make_host('unixhost', 'snaphost')
        host.stub( :exec ).and_return( true )


        Command.should_receive( :new ).with("sudo su -c \"cp -r .ssh /root/.\"").exactly( 1 ).times

        vagrant.copy_ssh_to_root( host )

      end

      it "can copy to Administrator on windows" do
        host = make_host('windowshost', 'snaphost', 'windows')
        host.stub( :exec ).and_return( true )

        Command.should_receive( :new ).with("sudo su -c \"cp -r .ssh /home/Administrator/.\"").exactly( 1 ).times

        vagrant.copy_ssh_to_root( host )

      end
    end

    it "can generate a ssh-config file" do
      host = make_host('myhost', 'mysnap')
      Dir.stub( :chdir ).and_yield()

      out = mock( 'stdout' )
      out.stub( :read ).and_return("Host #{host.name}
    HostName 127.0.0.1
    User vagrant
    Port 2222
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
    PasswordAuthentication no
    IdentityFile /home/root/.vagrant.d/insecure_private_key
    IdentitiesOnly yes")

      Open3.stub( :popen3 ).with( 'vagrant', 'ssh-config', host.name ).and_return( [ "", out ])

      file = mock( 'file' )
      file.stub( :path ).and_return( '/path/sshconfig' )
      file.stub( :rewind ).and_return( true )

      Tempfile.should_receive( :new ).with( "#{host.name}").and_return( file ) 
      file.should_receive( :write ).with("Host ip.address.for.myhost\n    HostName 127.0.0.1\n    User root\n    Port 2222\n    UserKnownHostsFile /dev/null\n    StrictHostKeyChecking no\n    PasswordAuthentication no\n    IdentityFile /home/root/.vagrant.d/insecure_private_key\n    IdentitiesOnly yes")

      vagrant.set_ssh_config( host, 'root' )
      expect( host['ssh'] ).to be === { :config => file.path }
      expect( host['user']).to be === 'root'

    end

    it "can provision a set of hosts" do

      vagrant.should_receive( :make_vfile ).with( @hosts ).exactly( 1 ).times

      vagrant.should_receive( :vagrant_cmd ).with( "halt" ).exactly( 1 ).times
      vagrant.should_receive( :vagrant_cmd ).with( "up" ).exactly( 1 ).times
      @hosts.each do |host|
        host_prev_name = host['user']
        vagrant.should_receive( :set_ssh_config ).with( host, 'vagrant' ).exactly( 1 ).times
        vagrant.should_receive( :copy_ssh_to_root ).with( host ).exactly( 1 ).times
        vagrant.should_receive( :set_ssh_config ).with( host, host_prev_name ).exactly( 1 ).times
      end
      vagrant.should_receive( :hack_etc_hosts ).with( @hosts ).exactly( 1 ).times


      vagrant.provision
    end

  end

end
