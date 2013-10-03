require 'spec_helper'

module Beaker
  module Utils
    describe SetupHelper do
      let( :logger ) { double( 'logger' ).as_null_object }
      let( :defaults ) { Beaker::Options::OptionsHash.new.merge( { :logger => logger} ) }
      let( :options ) { @options ? defaults.merge( @options ) : defaults}

      let( :setup_helper ) { Beaker::Utils::SetupHelper.new( options, @hosts) }

      let( :vms ) { ['vm1', 'vm2', 'vm3'] }
      let( :snaps )  { ['snapshot1', 'snapshot2', 'snapshot3'] }
      let( :roles_def ) { [ ['agent'], ['master', 'dashboard', 'agent', 'database'], ['agent'] ] }

      let( :ip ) { "ip.address.0.0" }
      let( :sync_cmd ) { Beaker::Utils::SetupHelper::ROOT_KEYS_SYNC_CMD }

      def make_host name, snap, roles, platform
        opts = Beaker::Options::OptionsHash.new.merge( { :logger => logger, 'HOSTS' => { name => { 'platform' => platform, :snapshot => snap, :roles => roles } } } )
        Host.create( name, opts )
      end

      def make_hosts names, snaps, roles_def, platform = 'unix'
        hosts = []
        names.zip(snaps, roles_def).each do |vm, snap, roles|
          hosts << make_host( vm, snap, roles, platform )
        end
        hosts
      end

      before :each do
        result = mock( 'result' )
        result.stub( :stdout ).and_return( ip )
        result.stub( :exit_code ).and_return( 0 )
        Host.any_instance.stub( :exec ) do
          result  
        end
      end

      context "add_master_entry" do
        
        it "can configure /etc/hosts on a unix master" do
          path = Beaker::Utils::SetupHelper::ETC_HOSTS_PATH
          @hosts = make_hosts( vms, snaps, roles_def )
          master = setup_helper.only_host_with_role(@hosts, :master)

          Command.should_receive( :new ).with( "ip a|awk '/g/{print$2}' | cut -d/ -f1 | head -1" ).exactly( 1 ).times
          Command.should_receive( :new ).with( "cp %s %s.old" % [path, path] ).exactly( 1 ).times
          Command.should_receive( :new ).with( "cp %s %s.new" % [path, path] ).exactly( 1 ).times
          Command.should_receive( :new ).with( "grep -v '#{ip} #{master}' %s > %s.new" % [path, path] ).exactly( 1 ).times
          Command.should_receive( :new ).with( "echo '#{ip} #{master}' >> %s.new" % path ).exactly( 1 ).times
          Command.should_receive( :new ).with( "mv %s.new %s" % [path, path] ).exactly( 1 ).times

          setup_helper.add_master_entry
        end

        it "can configure /etc/hosts on a solaris master" do
          path = Beaker::Utils::SetupHelper::ETC_HOSTS_PATH_SOLARIS
          @hosts = make_hosts( vms, snaps, roles_def, 'solaris' )
          master = setup_helper.only_host_with_role(@hosts, :master)

          Command.should_receive( :new ).with( "ifconfig -a inet| awk '/broadcast/ {print $2}' | cut -d/ -f1 | head -1" ).exactly( 1 ).times
          Command.should_receive( :new ).with( "cp %s %s.old" % [path, path] ).exactly( 1 ).times
          Command.should_receive( :new ).with( "cp %s %s.new" % [path, path] ).exactly( 1 ).times
          Command.should_receive( :new ).with( "grep -v '#{ip} #{master}' %s > %s.new" % [path, path] ).exactly( 1 ).times
          Command.should_receive( :new ).with( "echo '#{ip} #{master}' >> %s.new" % path ).exactly( 1 ).times
          Command.should_receive( :new ).with( "mv %s.new %s" % [path, path] ).exactly( 1 ).times

          setup_helper.add_master_entry
        end

        it "does nothing on a vagrant master" do
          @hosts = make_hosts( vms, snaps, roles_def )
          master = setup_helper.only_host_with_role(@hosts, :master)
          master[:hypervisor] = 'vagrant'

          Command.should_receive( :new ).exactly( 0 ).times
          
          setup_helper.add_master_entry

        end
      end

      context "sync_root_keys" do

        it "can sync keys on a solaris host" do
          @hosts = make_hosts( vms, snaps, roles_def, 'solaris' )

          Command.should_receive( :new ).with( sync_cmd % "bash" ).exactly( 3 ).times

          setup_helper.sync_root_keys

        end

        it "can sync keys on a non-solaris host" do
          @hosts = make_hosts( vms, snaps, roles_def )

          Command.should_receive( :new ).with( sync_cmd % "env PATH=/usr/gnu/bin:$PATH bash" ).exactly( 3 ).times

          setup_helper.sync_root_keys

        end

      end

    end
  end
end
