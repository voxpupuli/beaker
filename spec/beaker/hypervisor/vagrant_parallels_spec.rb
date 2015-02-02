require 'spec_helper'

describe Beaker::VagrantParallels do
  let( :options ) { make_opts.merge({ :hosts_file => 'sample.cfg', 'logger' => double().as_null_object }) }
  let( :vagrant ) { Beaker::VagrantParallels.new( @hosts, options ) }

  before :each do
    @hosts = make_hosts()
  end

  it "uses the parallels provider for provisioning" do
    @hosts.each do |host|
      host_prev_name = host['user']
      expect( vagrant ).to receive( :set_ssh_config ).with( host, 'vagrant' ).once
      expect( vagrant ).to receive( :copy_ssh_to_root ).with( host, options ).once
      expect( vagrant ).to receive( :set_ssh_config ).with( host, host_prev_name ).once
    end
    expect( vagrant ).to receive( :hack_etc_hosts ).with( @hosts, options ).once
    expect( vagrant ).to receive( :vagrant_cmd ).with( "up --provider parallels" ).once
    vagrant.provision
  end

  it "can make a Vagranfile for a set of hosts" do
    path = vagrant.instance_variable_get( :@vagrant_path )
    allow( vagrant ).to receive( :randmac ).and_return( "0123456789" )

    vagrant.make_vfile( @hosts )

    vagrantfile = File.read( File.expand_path( File.join( path, 'Vagrantfile' )))
    expect( vagrantfile ).to include( %Q{    v.vm.provider :parallels do |prl|\n      prl.optimize_power_consumption = false\n      prl.memory = '1024'\n    end})
  end

  it "can disable the auto-update functionality of the Parallels Guest Tools" do
    options.merge!({ :prl_update_guest_tools => 'disable' })

    vfile_section = vagrant.class.provider_vfile_section( @hosts.first, options )

    match = vfile_section.match(/prl.update_guest_tools = false/)

    expect( match ).to_not be nil

  end

end
