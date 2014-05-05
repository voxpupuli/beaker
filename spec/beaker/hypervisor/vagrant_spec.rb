require 'spec_helper'

module Beaker
  describe Vagrant do
    let( :options ) { make_opts.merge({ 'logger' => double().as_null_object }) }
    let( :vagrant ) { Beaker::Vagrant.new( @hosts, options ) }

    before :each do
      @hosts = make_hosts()
    end

    it "stores the vagrant file in $WORKINGDIR/.vagrant/beaker_vagrant_files/sample.cfg" do
      FakeFS.activate!
      vagrant.stub( :randmac ).and_return( "0123456789" )
      path = vagrant.instance_variable_get( :@vagrant_path )

      expect( path ).to be === File.join(Dir.pwd, '.vagrant', 'beaker_vagrant_files', 'sample.cfg')

    end

    it "can make a Vagranfile for a set of hosts" do
      FakeFS.activate!
      path = vagrant.instance_variable_get( :@vagrant_path )
      vagrant.stub( :randmac ).and_return( "0123456789" )

      vagrant.make_vfile( @hosts )

      expect( File.read( File.expand_path( File.join( path, "Vagrantfile") ) ) ).to be === "Vagrant.configure(\"2\") do |c|\n  c.vm.define 'vm1' do |v|\n    v.vm.hostname = 'vm1'\n    v.vm.box = 'vm1_of_my_box'\n    v.vm.box_url = 'http://address.for.my.box.vm1'\n    v.vm.base_mac = '0123456789'\n    v.vm.network :private_network, ip: \"ip.address.for.vm1\", :netmask => \"255.255.0.0\"\n  end\n  c.vm.define 'vm2' do |v|\n    v.vm.hostname = 'vm2'\n    v.vm.box = 'vm2_of_my_box'\n    v.vm.box_url = 'http://address.for.my.box.vm2'\n    v.vm.base_mac = '0123456789'\n    v.vm.network :private_network, ip: \"ip.address.for.vm2\", :netmask => \"255.255.0.0\"\n  end\n  c.vm.define 'vm3' do |v|\n    v.vm.hostname = 'vm3'\n    v.vm.box = 'vm3_of_my_box'\n    v.vm.box_url = 'http://address.for.my.box.vm3'\n    v.vm.base_mac = '0123456789'\n    v.vm.network :private_network, ip: \"ip.address.for.vm3\", :netmask => \"255.255.0.0\"\n  end\n  c.vm.provider :virtualbox do |vb|\n    vb.customize [\"modifyvm\", :id, \"--memory\", \"1024\"]\n  end\nend\n"
    end

    it "generates a valid windows config" do
      FakeFS.activate!
      path = vagrant.instance_variable_get( :@vagrant_path )
      vagrant.stub( :randmac ).and_return( "0123456789" )
      @hosts[0][:platform] = 'windows'

      vagrant.make_vfile( @hosts )

      generated_file = File.read( File.expand_path( File.join( path, "Vagrantfile") ) )

      match = generated_file.match(/v.vm.network :forwarded_port, guest: 3389, host: 3389/)
      expect( match ).to_not be_nil,'Should have proper port for RDP'

      match = generated_file.match(/v.vm.network :forwarded_port, guest: 5985, host: 5985, id: 'winrm', auto_correct: true/)
      expect( match ).to_not be_nil, "Should have proper port for WinRM"

      match = generated_file.match(/v.vm.guest = :windows/)
      expect( match ).to_not be_nil, 'Should correctly identify guest OS so Vagrant can act accordingly'


    end

    it "uses the memsize defined per vagrant host" do
      FakeFS.activate!
      path = vagrant.instance_variable_get( :@vagrant_path )
      vagrant.stub( :randmac ).and_return( "0123456789" )

      vagrant.make_vfile( @hosts, {'vagrant_memsize' => 'hello!'} )

      generated_file = File.read( File.expand_path( File.join( path, "Vagrantfile") ) )

      match = generated_file.match(/vb.customize \["modifyvm", :id, "--memory", "hello!"\]/)

      expect( match ).to_not be nil

    end

    it "can generate a new /etc/hosts file referencing each host" do

      @hosts.each do |host|
        vagrant.should_receive( :set_etc_hosts ).with( host, "127.0.0.1\tlocalhost localhost.localdomain\nip.address.for.vm1\tvm1\nip.address.for.vm2\tvm2\nip.address.for.vm3\tvm3\n" ).once
      end

      vagrant.hack_etc_hosts( @hosts, options )

    end

    context "can copy vagrant's key to root .ssh on each host" do

      it "can copy to root on unix" do
        host = @hosts[0]
        host[:platform] = 'unix'

        Command.should_receive( :new ).with("sudo su -c \"cp -r .ssh /root/.\"").once

        vagrant.copy_ssh_to_root( host, options )

      end

      it "can copy to Administrator on windows" do
        host = @hosts[0]
        host[:platform] = 'windows'

        Command.should_receive( :new ).with("cp -r .ssh /cygdrive/c/Users/Administrator/.").once
        Command.should_receive( :new ).with("chown -R Administrator /cygdrive/c/Users/Administrator/.ssh").once

        vagrant.copy_ssh_to_root( host, options )

      end
    end

    it "can generate a ssh-config file" do
      host = @hosts[0]
      name = host.name
      Dir.stub( :chdir ).and_yield()

      vagrant.should_receive(:`).and_return("Host #{host.name}
    HostName 127.0.0.1
    User vagrant
    Port 2222
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
    PasswordAuthentication no
    IdentityFile /home/root/.vagrant.d/insecure_private_key
    IdentitiesOnly yes")

      file = double( 'file' )
      file.stub( :path ).and_return( '/path/sshconfig' )
      file.stub( :rewind ).and_return( true )

      Tempfile.should_receive( :new ).with( "#{host.name}").and_return( file ) 
      file.should_receive( :write ).with("Host ip.address.for.#{name}\n    HostName 127.0.0.1\n    User root\n    Port 2222\n    UserKnownHostsFile /dev/null\n    StrictHostKeyChecking no\n    PasswordAuthentication no\n    IdentityFile /home/root/.vagrant.d/insecure_private_key\n    IdentitiesOnly yes")

      vagrant.set_ssh_config( host, 'root' )
      expect( host['ssh'] ).to be === { :config => file.path }
      expect( host['user']).to be === 'root'

    end

    describe "get_ip_from_vagrant_file" do
      before :each do
        FakeFS.activate!
        vagrant.stub( :randmac ).and_return( "0123456789" )
        vagrant.make_vfile( @hosts )
      end

      it "can find the correct ip for the provided hostname" do
        @hosts.each do |host|
          expect( vagrant.get_ip_from_vagrant_file(host.name) ).to be === host[:ip]
        end

      end

      it "raises an error if it is unable to find an ip" do
        expect{ vagrant.get_ip_from_vagrant_file("unknown") }.to raise_error

      end

      it "raises an error if no Vagrantfile is present" do
        File.delete( vagrant.instance_variable_get( :@vagrant_file ) )
        @hosts.each do |host|
          expect{ vagrant.get_ip_from_vagrant_file(host.name) }.to raise_error
        end
      end

    end

    describe "provisioning and cleanup" do

      before :each do
        FakeFS.activate!
        vagrant.should_receive( :vagrant_cmd ).with( "up" ).once
        @hosts.each do |host|
          host_prev_name = host['user']
          vagrant.should_receive( :set_ssh_config ).with( host, 'vagrant' ).once
          vagrant.should_receive( :copy_ssh_to_root ).with( host, options ).once
          vagrant.should_receive( :set_ssh_config ).with( host, host_prev_name ).once
        end
        vagrant.should_receive( :hack_etc_hosts ).with( @hosts, options ).once
      end

      it "can provision a set of hosts" do
        options = vagrant.instance_variable_get( :@options )
        vagrant.should_receive( :make_vfile ).with( @hosts, options ).once
        vagrant.should_receive( :vagrant_cmd ).with( "destroy --force" ).never
        vagrant.provision
      end

      it "destroys an existing set of hosts before provisioning" do
        vagrant.make_vfile( @hosts )
        vagrant.should_receive( :vagrant_cmd ).with( "destroy --force" ).once
        vagrant.provision
      end

      it "can cleanup" do
        vagrant.should_receive( :vagrant_cmd ).with( "destroy --force" ).once
        FileUtils.should_receive( :rm_rf ).once

        vagrant.provision
        vagrant.cleanup

      end

    end

  end

end
