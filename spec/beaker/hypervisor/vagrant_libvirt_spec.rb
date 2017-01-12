require 'spec_helper'

describe Beaker::VagrantLibvirt do
  let( :options ) { make_opts.merge({ :hosts_file => 'sample.cfg',
                                      'logger' => double().as_null_object,
                                      'libvirt' => { 'uri' => 'qemu+ssh://root@host/system'},
                                      'vagrant_cpus' => 2,
                                    }) }
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

  context 'Correct vagrant configuration' do
    before(:each) do
      FakeFS.activate!
      path = vagrant.instance_variable_get( :@vagrant_path )

      vagrant.make_vfile( @hosts, options )
      @vagrantfile = File.read( File.expand_path( File.join( path, "Vagrantfile")))
    end

    it "can make a Vagranfile for a set of hosts" do
      expect( @vagrantfile ).to include( %Q{    v.vm.provider :libvirt do |node|})
    end

    it "can specify the memory as an integer" do
      expect( @vagrantfile.split("\n").map(&:strip) )
        .to include('node.memory = 1024')
    end

    it "can specify the number of cpus" do
      expect( @vagrantfile.split("\n").map(&:strip) )
        .to include("node.cpus = 2")
    end

    it "can specify any libvirt option" do
      expect( @vagrantfile.split("\n").map(&:strip) )
        .to include("node.uri = 'qemu+ssh://root@host/system'")
    end

    it "has a mac address in the proper format" do
      expect( @vagrantfile.split("\n").map(&:strip) )
        .to include(/:mac => "08:00:27:\h{2}:\h{2}:\h{2}"/)
    end
  end
end
