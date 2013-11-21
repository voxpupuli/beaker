require 'spec_helper'

module Beaker
  describe Vagrant do
    let( :vagrant ) { Beaker::Vagrant.new( @hosts, make_opts ) }

    before :each do
      @hosts = make_hosts()
    end

    it "can make a Vagranfile for a set of hosts" do
      FakeFS.activate!
      path = vagrant.instance_variable_get( :@vagrant_path )
      vagrant.stub( :randmac ).and_return( "0123456789" )

      vagrant.make_vfile( @hosts )

      expect( File.read( File.expand_path( File.join( path, "Vagrantfile") ) ) ).to be === "Vagrant.configure(\"2\") do |c|\n  c.vm.define 'vm1' do |v|\n    v.vm.hostname = 'vm1'\n    v.vm.box = 'vm1_of_my_box'\n    v.vm.box_url = 'http://address.for.my.box.vm1'\n    v.vm.base_mac = '0123456789'\n    v.vm.network :private_network, ip: \"ip.address.for.vm1\", :netmask => \"255.255.0.0\"\n  end\n  c.vm.define 'vm2' do |v|\n    v.vm.hostname = 'vm2'\n    v.vm.box = 'vm2_of_my_box'\n    v.vm.box_url = 'http://address.for.my.box.vm2'\n    v.vm.base_mac = '0123456789'\n    v.vm.network :private_network, ip: \"ip.address.for.vm2\", :netmask => \"255.255.0.0\"\n  end\n  c.vm.define 'vm3' do |v|\n    v.vm.hostname = 'vm3'\n    v.vm.box = 'vm3_of_my_box'\n    v.vm.box_url = 'http://address.for.my.box.vm3'\n    v.vm.base_mac = '0123456789'\n    v.vm.network :private_network, ip: \"ip.address.for.vm3\", :netmask => \"255.255.0.0\"\n  end\n  c.vm.provider :virtualbox do |vb|\n    vb.customize [\"modifyvm\", :id, \"--memory\", \"1024\"]\n  end\nend\n"
    end

    it "can generate a new /etc/hosts file referencing each host" do

      @hosts.each do |host|
        vagrant.should_receive( :set_etc_hosts ).with( host, "127.0.0.1\tlocalhost localhost.localdomain\nip.address.for.vm1\tvm1\nip.address.for.vm2\tvm2\nip.address.for.vm3\tvm3\n" ).once
      end

      vagrant.hack_etc_hosts( @hosts )

    end

    context "can copy vagrant's key to root .ssh on each host" do

      it "can copy to root on unix" do
        host = @hosts[0]
        host[:platform] = 'unix'

        Command.should_receive( :new ).with("sudo su -c \"cp -r .ssh /root/.\"").once

        vagrant.copy_ssh_to_root( host )

      end

      it "can copy to Administrator on windows" do
        host = @hosts[0]
        host[:platform] = 'windows'

        Command.should_receive( :new ).with("sudo su -c \"cp -r .ssh /home/Administrator/.\"").once

        vagrant.copy_ssh_to_root( host )

      end
    end

    it "can generate a ssh-config file" do
      host = @hosts[0]
      name = host.name
      Dir.stub( :chdir ).and_yield()

      out = double( 'stdout' )
      out.stub( :read ).and_return("Host #{host.name}
    HostName 127.0.0.1
    User vagrant
    Port 2222
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
    PasswordAuthentication no
    IdentityFile /home/root/.vagrant.d/insecure_private_key
    IdentitiesOnly yes")
      wait_thr = OpenStruct.new
      state = mock( 'state' )
      state.stub( :success? ).and_return( true )
      wait_thr.value = state

      Open3.stub( :popen3 ).with( 'vagrant', 'ssh-config', host.name ).and_return( [ "", out, "", wait_thr ])

      file = double( 'file' )
      file.stub( :path ).and_return( '/path/sshconfig' )
      file.stub( :rewind ).and_return( true )

      Tempfile.should_receive( :new ).with( "#{host.name}").and_return( file ) 
      file.should_receive( :write ).with("Host ip.address.for.#{name}\n    HostName 127.0.0.1\n    User root\n    Port 2222\n    UserKnownHostsFile /dev/null\n    StrictHostKeyChecking no\n    PasswordAuthentication no\n    IdentityFile /home/root/.vagrant.d/insecure_private_key\n    IdentitiesOnly yes")

      vagrant.set_ssh_config( host, 'root' )
      expect( host['ssh'] ).to be === { :config => file.path }
      expect( host['user']).to be === 'root'

    end

    describe "provisioning and cleanup" do

      before :each do
        FakeFS.activate!
        vagrant.should_receive( :vagrant_cmd ).with( "up" ).once
        @hosts.each do |host|
          host_prev_name = host['user']
          vagrant.should_receive( :set_ssh_config ).with( host, 'vagrant' ).once
          vagrant.should_receive( :copy_ssh_to_root ).with( host ).once
          vagrant.should_receive( :set_ssh_config ).with( host, host_prev_name ).once
        end
        vagrant.should_receive( :hack_etc_hosts ).with( @hosts ).once
      end

      it "can provision a set of hosts" do
        vagrant.should_receive( :make_vfile ).with( @hosts ).once
        vagrant.should_receive( :vagrant_cmd ).with( "destroy --force" ).never
        vagrant.provision
      end

      it "destroys an existing set of hosts before provisioning" do
        vagrant.make_vfile(@hosts)
        vagrant.should_receive(:vagrant_cmd).with("destroy --force").once
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
