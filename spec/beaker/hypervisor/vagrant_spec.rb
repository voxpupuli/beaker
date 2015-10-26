require 'spec_helper'

module Beaker
  describe Vagrant do

    let( :options ) {
      make_opts.merge({
        'logger' => double().as_null_object,
        :hosts_file => 'sample.cfg',
        :forward_ssh_agent => true,
      })
    }

    let( :vagrant ) { Beaker::Vagrant.new( @hosts, options ) }

    before :each do
      @hosts = make_hosts()
    end

    it "stores the vagrant file in $WORKINGDIR/.vagrant/beaker_vagrant_files/sample.cfg" do
      allow( vagrant ).to receive( :randmac ).and_return( "0123456789" )
      path = vagrant.instance_variable_get( :@vagrant_path )

      expect( path ).to be === File.join(Dir.pwd, '.vagrant', 'beaker_vagrant_files', 'sample.cfg')

    end

    it "can make a Vagrantfile for a set of hosts" do
      path = vagrant.instance_variable_get( :@vagrant_path )
      allow( vagrant ).to receive( :randmac ).and_return( "0123456789" )

      vagrant.make_vfile( @hosts )

      vagrantfile = File.read( File.expand_path( File.join( path, "Vagrantfile")))
      expect( vagrantfile ).to be === <<-EOF
Vagrant.configure("2") do |c|
  c.ssh.insert_key = false
  c.vm.define 'vm1' do |v|
    v.vm.hostname = 'vm1'
    v.vm.box = 'vm1_of_my_box'
    v.vm.box_url = 'http://address.for.my.box.vm1'
    v.vm.box_check_update = 'true'
    v.vm.network :private_network, ip: "ip.address.for.vm1", :netmask => "255.255.0.0", :mac => "0123456789"
    v.vm.provider :virtualbox do |vb|
      vb.customize ['modifyvm', :id, '--memory', '1024', '--cpus', '1']
    end
  end
  c.vm.define 'vm2' do |v|
    v.vm.hostname = 'vm2'
    v.vm.box = 'vm2_of_my_box'
    v.vm.box_url = 'http://address.for.my.box.vm2'
    v.vm.box_check_update = 'true'
    v.vm.network :private_network, ip: "ip.address.for.vm2", :netmask => "255.255.0.0", :mac => "0123456789"
    v.vm.provider :virtualbox do |vb|
      vb.customize ['modifyvm', :id, '--memory', '1024', '--cpus', '1']
    end
  end
  c.vm.define 'vm3' do |v|
    v.vm.hostname = 'vm3'
    v.vm.box = 'vm3_of_my_box'
    v.vm.box_url = 'http://address.for.my.box.vm3'
    v.vm.box_check_update = 'true'
    v.vm.network :private_network, ip: "ip.address.for.vm3", :netmask => "255.255.0.0", :mac => "0123456789"
    v.vm.provider :virtualbox do |vb|
      vb.customize ['modifyvm', :id, '--memory', '1024', '--cpus', '1']
    end
  end
end
EOF
    end

    it "can make a Vagrantfile with ssh agent forwarding enabled" do
      path = vagrant.instance_variable_get( :@vagrant_path )
      allow( vagrant ).to receive( :randmac ).and_return( "0123456789" )

      hosts = make_hosts({},1)
      vagrant.make_vfile( hosts, options )

      vagrantfile = File.read( File.expand_path( File.join( path, "Vagrantfile")))
      expect( vagrantfile ).to match(/(ssh.forward_agent = true)/)
    end

    it "can make a Vagrantfile with synced_folder disabled" do
      path = vagrant.instance_variable_get( :@vagrant_path )
      allow( vagrant ).to receive( :randmac ).and_return( "0123456789" )

      hosts = make_hosts({:synced_folder => 'disabled'},1)
      vagrant.make_vfile( hosts, options )

      vagrantfile = File.read( File.expand_path( File.join( path, "Vagrantfile")))
      expect( vagrantfile ).to match(/v.vm.synced_folder .* disabled: true/)
    end

    it "generates a valid windows config" do
      path = vagrant.instance_variable_get( :@vagrant_path )
      allow( vagrant ).to receive( :randmac ).and_return( "0123456789" )
      @hosts[0][:platform] = 'windows'

      vagrant.make_vfile( @hosts )

      generated_file = File.read( File.expand_path( File.join( path, "Vagrantfile") ) )

      match = generated_file.match(/v.vm.network :forwarded_port, guest: 3389, host: 3389, id: 'rdp', auto_correct: true/)
      expect( match ).to_not be_nil,'Should have proper port for RDP'

      match = generated_file.match(/v.vm.network :forwarded_port, guest: 5985, host: 5985, id: 'winrm', auto_correct: true/)
      expect( match ).to_not be_nil, "Should have proper port for WinRM"

      match = generated_file.match(/v.vm.guest = :windows/)
      expect( match ).to_not be_nil, 'Should correctly identify guest OS so Vagrant can act accordingly'


    end

    it "uses the memsize defined per vagrant host" do
      path = vagrant.instance_variable_get( :@vagrant_path )
      allow( vagrant ).to receive( :randmac ).and_return( "0123456789" )

      vagrant.make_vfile( @hosts, {'vagrant_memsize' => 'hello!'} )

      generated_file = File.read( File.expand_path( File.join( path, "Vagrantfile") ) )

      match = generated_file.match(/vb.customize \['modifyvm', :id, '--memory', 'hello!', '--cpus', '1'\]/)

      expect( match ).to_not be nil

    end
    
    it "uses the cpus defined per vagrant host" do
      path = vagrant.instance_variable_get( :@vagrant_path )
      allow( vagrant ).to receive( :randmac ).and_return( "0123456789" )
  
      vagrant.make_vfile( @hosts, {'vagrant_cpus' => 'goodbye!'} )
  
      generated_file = File.read( File.expand_path( File.join( path, "Vagrantfile") ) )
  
      match = generated_file.match(/vb.customize \['modifyvm', :id, '--memory', '1024', '--cpus', 'goodbye!'\]/)
  
      expect( match ).to_not be nil
  
    end

    it "can generate a new /etc/hosts file referencing each host" do

      @hosts.each do |host|
        expect( vagrant ).to receive( :get_domain_name ).with( host ).and_return( 'labs.lan' )
        expect( vagrant ).to receive( :set_etc_hosts ).with( host, "127.0.0.1\tlocalhost localhost.localdomain\nip.address.for.vm1\tvm1.labs.lan vm1\nip.address.for.vm2\tvm2.labs.lan vm2\nip.address.for.vm3\tvm3.labs.lan vm3\n" ).once
      end

      vagrant.hack_etc_hosts( @hosts, options )

    end

    context "can copy vagrant's key to root .ssh on each host" do

      it "can copy to root on unix" do
        host = @hosts[0]
        host[:platform] = 'unix'

        expect( Command ).to receive( :new ).with("sudo su -c \"cp -r .ssh /root/.\"").once

        vagrant.copy_ssh_to_root( host, options )

      end

      it "can copy to Administrator on windows" do
        host = @hosts[0]
        host[:platform] = 'windows'
        expect( host ).to receive( :is_cygwin? ).and_return(true)

        expect( Command ).to receive( :new ).with("cp -r .ssh /cygdrive/c/Users/Administrator/.").once
        expect( Command ).to receive( :new ).with("chown -R Administrator /cygdrive/c/Users/Administrator/.ssh").once

        vagrant.copy_ssh_to_root( host, options )

      end
    end

    it "can generate a ssh-config file" do
      host = @hosts[0]
      name = host.name
      allow( Dir ).to receive( :chdir ).and_yield()
      out = double( 'stdout' )
      allow( out ).to receive( :read ).and_return("Host #{name}
    HostName 127.0.0.1
    User vagrant
    Port 2222
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
    PasswordAuthentication no
    IdentityFile /home/root/.vagrant.d/insecure_private_key
    IdentitiesOnly yes")

      wait_thr = OpenStruct.new
      state = double( 'state' )
      allow( state ).to receive( :success? ).and_return( true )
      wait_thr.value = state

      allow( Open3 ).to receive( :popen3 ).with( 'vagrant', 'ssh-config', name ).and_return( [ "", out, "", wait_thr ])

      file = double( 'file' )
      allow( file ).to receive( :path ).and_return( '/path/sshconfig' )
      allow( file ).to receive( :rewind ).and_return( true )

      expect( Tempfile ).to receive( :new ).with( "#{host.name}").and_return( file )
      expect( file ).to receive( :write ).with("Host ip.address.for.#{name}\n    HostName 127.0.0.1\n    User root\n    Port 2222\n    UserKnownHostsFile /dev/null\n    StrictHostKeyChecking no\n    PasswordAuthentication no\n    IdentityFile /home/root/.vagrant.d/insecure_private_key\n    IdentitiesOnly yes")

      vagrant.set_ssh_config( host, 'root' )
      expect( host['ssh'] ).to be === { :config => file.path }
      expect( host['user']).to be === 'root'

    end

    describe "get_ip_from_vagrant_file" do
      before :each do
        allow( vagrant ).to receive( :randmac ).and_return( "0123456789" )
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
        expect( vagrant ).to receive( :vagrant_cmd ).with( "up" ).once
        @hosts.each do |host|
          host_prev_name = host['user']
          expect( vagrant ).to receive( :set_ssh_config ).with( host, 'vagrant' ).once
          expect( vagrant ).to receive( :copy_ssh_to_root ).with( host, options ).once
          expect( vagrant ).to receive( :set_ssh_config ).with( host, host_prev_name ).once
        end
        expect( vagrant ).to receive( :hack_etc_hosts ).with( @hosts, options ).once
      end

      it "can provision a set of hosts" do
        options = vagrant.instance_variable_get( :@options )
        expect( vagrant ).to receive( :make_vfile ).with( @hosts, options ).once
        expect( vagrant ).to receive( :vagrant_cmd ).with( "destroy --force" ).never
        vagrant.provision
      end

      it "destroys an existing set of hosts before provisioning" do
        vagrant.make_vfile( @hosts )
        expect( vagrant ).to receive( :vagrant_cmd ).with( "destroy --force" ).once
        vagrant.provision
      end

      it "can cleanup" do
        expect( vagrant ).to receive( :vagrant_cmd ).with( "destroy --force" ).once
        expect( FileUtils ).to receive( :rm_rf ).once

        vagrant.provision
        vagrant.cleanup

      end

    end

  end

end
