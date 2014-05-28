require 'spec_helper'

describe Beaker::VagrantVirtualbox do
  let( :options ) { make_opts.merge({ 'logger' => double().as_null_object }) }
  let( :vagrant ) { Beaker::VagrantVirtualbox.new( @hosts, options ) }

  before :each do
    @hosts = make_hosts()
  end

  it "uses the virtualbox provider for provisioning" do
    @hosts.each do |host|
      host_prev_name = host['user']
      vagrant.should_receive( :set_ssh_config ).with( host, 'vagrant' ).once
      vagrant.should_receive( :copy_ssh_to_root ).with( host, options ).once
      vagrant.should_receive( :set_ssh_config ).with( host, host_prev_name ).once
    end
    vagrant.should_receive( :hack_etc_hosts ).with( @hosts, options ).once
    FakeFS.activate!
    vagrant.should_receive( :vagrant_cmd ).with( "up --provider virtualbox" ).once
    vagrant.provision
  end

  it "can make a Vagranfile for a set of hosts" do
    FakeFS.activate!
    path = vagrant.instance_variable_get( :@vagrant_path )
    vagrant.stub( :randmac ).and_return( "0123456789" )

    vagrant.make_vfile( @hosts )

    expect( File.read( File.expand_path( File.join( path, "Vagrantfile") ) ) ).to be === "Vagrant.configure(\"2\") do |c|\n  c.vm.define 'vm1' do |v|\n    v.vm.hostname = 'vm1'\n    v.vm.box = 'vm1_of_my_box'\n    v.vm.box_url = 'http://address.for.my.box.vm1'\n    v.vm.base_mac = '0123456789'\n    v.vm.network :private_network, ip: \"ip.address.for.vm1\", :netmask => \"255.255.0.0\"\n  end\n  c.vm.define 'vm2' do |v|\n    v.vm.hostname = 'vm2'\n    v.vm.box = 'vm2_of_my_box'\n    v.vm.box_url = 'http://address.for.my.box.vm2'\n    v.vm.base_mac = '0123456789'\n    v.vm.network :private_network, ip: \"ip.address.for.vm2\", :netmask => \"255.255.0.0\"\n  end\n  c.vm.define 'vm3' do |v|\n    v.vm.hostname = 'vm3'\n    v.vm.box = 'vm3_of_my_box'\n    v.vm.box_url = 'http://address.for.my.box.vm3'\n    v.vm.base_mac = '0123456789'\n    v.vm.network :private_network, ip: \"ip.address.for.vm3\", :netmask => \"255.255.0.0\"\n  end\n  c.vm.provider :virtualbox do |vb|\n    vb.customize [\"modifyvm\", :id, \"--memory\", \"1024\"]\n  end\nend\n"
  end
end
