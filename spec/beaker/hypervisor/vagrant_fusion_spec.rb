require 'spec_helper'

describe Beaker::VagrantFusion do
  let( :options ) { make_opts.merge({ :hosts_file => 'sample.cfg', 'logger' => double().as_null_object }) }
  let( :vagrant ) { Beaker::VagrantFusion.new( @hosts, options ) }

  before :each do
    @hosts = make_hosts()
  end

  it "uses the vmware_fusion provider for provisioning" do
    @hosts.each do |host|
      host_prev_name = host['user']
      vagrant.should_receive( :set_ssh_config ).with( host, 'vagrant' ).once
      vagrant.should_receive( :copy_ssh_to_root ).with( host, options ).once
      vagrant.should_receive( :set_ssh_config ).with( host, host_prev_name ).once
    end
    vagrant.should_receive( :hack_etc_hosts ).with( @hosts, options ).once
    FakeFS.activate!
    vagrant.should_receive( :vagrant_cmd ).with( "up --provider vmware_fusion" ).once
    vagrant.provision
  end

  it "can make a Vagranfile for a set of hosts" do
    FakeFS.activate!
    path = vagrant.instance_variable_get( :@vagrant_path )
    vagrant.stub( :randmac ).and_return( "0123456789" )

    vagrant.make_vfile( @hosts )

    vagrantfile = File.read( File.expand_path( File.join( path, "Vagrantfile")))
    expect( vagrantfile ).to include( %Q{    v.vm.provider :vmware_fusion do |v|\n      v.vmx['memsize'] = '1024'\n    end})
  end
end
