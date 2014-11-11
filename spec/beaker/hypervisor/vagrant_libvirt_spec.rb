require 'spec_helper'

describe Beaker::VagrantLibvirt do
  let( :options ) { make_opts.merge({ :hosts_file => 'sample.cfg', 'logger' => double().as_null_object }) }
  let( :vagrant ) { Beaker::VagrantLibvirt.new( @hosts, options ) }

  before :each do
    @hosts = make_hosts()
  end

  it "uses the vagrant_libvirt provider for provisioning" do
    @hosts.each do |host|
      host_prev_name = host['user']
      expect( vagrant ).to receive( :set_ssh_config ).with( host, 'vagrant' ).once
      expect( vagrant ).to receive( :copy_ssh_to_root ).with( host, options ).once
      expect( vagrant ).to receive( :set_ssh_config ).with( host, host_prev_name ).once
    end
    expect( vagrant ).to receive( :hack_etc_hosts ).with( @hosts, options ).once
    FakeFS.activate!
    expect( vagrant ).to receive( :vagrant_cmd ).with( "up --provider libvirt" ).once
    vagrant.provision
  end

  it "can make a Vagranfile for a set of hosts" do
    FakeFS.activate!
    path = vagrant.instance_variable_get( :@vagrant_path )
    allow( vagrant ).to receive( :randmac ).and_return( "0123456789" )

    vagrant.make_vfile( @hosts )

    vagrantfile = File.read( File.expand_path( File.join( path, "Vagrantfile")))
    expect( vagrantfile ).to include( %Q{    v.vm.provider :libvirt})
  end
end
