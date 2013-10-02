require 'spec_helper'

module Beaker
  describe Aixer do
    let( :logger ) { double( 'logger' ).as_null_object }
    let( :defaults ) { Beaker::Options::Presets.presets.merge(Beaker::Options::OptionsHash.new.merge( { :logger => logger} )) }
    let( :options ) { @options ? defaults.merge( @options ) : defaults}

    let( :solaris) { Beaker::Solaris.new( @hosts, options ) }
    let( :vms ) { ['vm1', 'vm2', 'vm3'] }
    let( :snaps )  { ['snapshot1', 'snapshot2', 'snapshot3'] }

    def make_host name, snap
      opts = Beaker::Options::OptionsHash.new.merge( { :logger => logger, 'HOSTS' => { name => { 'platform' => 'unix', :snapshot => snap } } } )
      Host.create( name, opts )
    end

    def make_hosts names, snaps
      hosts = []
      names.zip(snaps).each do |vm, snap|
        hosts << make_host( vm, snap )
      end
      hosts
    end

    before :each do
      File.stub( :exists? ).and_return( true )
      YAML.stub( :load_file ).and_return({:default=>{:aws_access_key_id=>"IMANACCESSKEY", :aws_secret_access_key=>"supersekritkey", :aix_hypervisor_server=>"aix_hypervisor.labs.net", :aix_hypervisor_username=>"aixer", :aix_hypervisor_keyfile=>"/Users/user/.ssh/id_rsa-acceptance", :solaris_hypervisor_server=>"solaris_hypervisor.labs.net", :solaris_hypervisor_username=>"harness", :solaris_hypervisor_keyfile=>"/Users/user/.ssh/id_rsa-old.private", :solaris_hypervisor_vmpath=>"rpoooool/zs", :solaris_hypervisor_snappaths=>["rpoooool/USER/z0"], :vsphere_server=>"vsphere.labs.net", :vsphere_username=>"vsphere@labs.com", :vsphere_password=>"supersekritpassword"}})
      Host.any_instance.stub( :exec ).and_return( true )

    end

    it "can provision a set of hosts" do
      @hosts = make_hosts( vms, snaps )
      vmpath = "rpoooool/zs"
      spath = "rpoooool/USER/z0"

      @hosts.each do |host|
        vm_name = host['vmname'] || host.name
        snapshot = host['snapshot']
        Command.should_receive( :new ).with("sudo /sbin/zfs rollback -Rf #{vmpath}/#{vm_name}@#{snapshot}").exactly( 1 ).times
        Command.should_receive( :new ).with("sudo /sbin/zfs rollback -Rf #{vmpath}/#{vm_name}/#{spath}@#{snapshot}").exactly( 1 ).times
        Command.should_receive( :new ).with("sudo /sbin/zoneadm -z #{vm_name} boot").exactly( 1 ).times


      end

      solaris.provision

    end

    it "does nothing for cleanup" do
      @hosts = make_hosts( vms, snaps )
      Command.should_receive( :new ).exactly( 0 ).times
      Host.should_receive( :exec ).exactly( 0 ).times

      solaris.cleanup
    end


  end

end
