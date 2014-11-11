require 'spec_helper'

module Beaker
  describe Solaris do
    let( :solaris) { Beaker::Solaris.new( @hosts, make_opts ) }

    before :each do
      @hosts = make_hosts()
      allow( File ).to receive( :exists? ).and_return( true )
      allow( YAML ).to receive( :load_file ).and_return( fog_file_contents )
      allow_any_instance_of( Host ).to receive( :exec ).and_return( true )
    end

    it "can provision a set of hosts" do
      vmpath = "rpoooool/zs"
      spath = "rpoooool/USER/z0"

      @hosts.each do |host|
        vm_name = host['vmname'] || host.name
        snapshot = host['snapshot']
        expect( Command ).to receive( :new ).with("sudo /sbin/zfs rollback -Rf #{vmpath}/#{vm_name}@#{snapshot}").once
        expect( Command ).to receive( :new ).with("sudo /sbin/zfs rollback -Rf #{vmpath}/#{vm_name}/#{spath}@#{snapshot}").once
        expect( Command ).to receive( :new ).with("sudo /sbin/zoneadm -z #{vm_name} boot").once
      end

      solaris.provision
    end

    it "does nothing for cleanup" do
      expect( Command ).to receive( :new ).never
      expect( Host ).to receive( :exec ).never

      solaris.cleanup
    end


  end

end
