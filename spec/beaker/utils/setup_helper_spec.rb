require 'spec_helper'

module Beaker
  module Utils
    describe SetupHelper do
      let( :setup_helper ) { Beaker::Utils::SetupHelper.new( make_opts, hosts) }
      let( :sync_cmd )     { Beaker::Utils::SetupHelper::ROOT_KEYS_SYNC_CMD }
      let( :platform )     { @platform || 'unix' }
      let( :ip )           { "ip.address.0.0" }
      let( :stdout)        { @stdout || ip }
      let( :hosts )        { hosts = make_hosts( { :stdout => stdout, :platform => platform } )
                             hosts[0][:roles] = ['agent']
                             hosts[1][:roles] = ['master', 'dashboard', 'agent', 'database']
                             hosts[2][:roles] = ['agent']
                             hosts }

      context "add_master_entry" do
        
        it "can configure /etc/hosts on a unix master" do
          path = Beaker::Utils::SetupHelper::ETC_HOSTS_PATH
          master = setup_helper.only_host_with_role(hosts, :master)

          Command.should_receive( :new ).with( "ip a|awk '/g/{print$2}' | cut -d/ -f1 | head -1" ).once
          Command.should_receive( :new ).with( "cp %s %s.old" % [path, path] ).once
          Command.should_receive( :new ).with( "cp %s %s.new" % [path, path] ).once
          Command.should_receive( :new ).with( "grep -v '#{ip} #{master}' %s > %s.new" % [path, path] ).once
          Command.should_receive( :new ).with( "echo '#{ip} #{master}' >> %s.new" % path ).once
          Command.should_receive( :new ).with( "mv %s.new %s" % [path, path] ).once

          setup_helper.add_master_entry
        end

        it "can configure /etc/hosts on a solaris master" do
          @platform = 'solaris'
          path = Beaker::Utils::SetupHelper::ETC_HOSTS_PATH_SOLARIS
          master = setup_helper.only_host_with_role(hosts, :master)

          Command.should_receive( :new ).with( "ifconfig -a inet| awk '/broadcast/ {print $2}' | cut -d/ -f1 | head -1" ).once
          Command.should_receive( :new ).with( "cp %s %s.old" % [path, path] ).once
          Command.should_receive( :new ).with( "cp %s %s.new" % [path, path] ).once
          Command.should_receive( :new ).with( "grep -v '#{ip} #{master}' %s > %s.new" % [path, path] ).once
          Command.should_receive( :new ).with( "echo '#{ip} #{master}' >> %s.new" % path ).once
          Command.should_receive( :new ).with( "mv %s.new %s" % [path, path] ).once

          setup_helper.add_master_entry
        end

        it "does nothing on a vagrant master" do
          master = setup_helper.only_host_with_role(hosts, :master)
          master[:hypervisor] = 'vagrant'

          Command.should_receive( :new ).never
          
          setup_helper.add_master_entry

        end
      end

      context "sync_root_keys" do

        it "can sync keys on a solaris host" do
          @platform = 'solaris'

          Command.should_receive( :new ).with( sync_cmd % "bash" ).exactly( 3 ).times

          setup_helper.sync_root_keys

        end

        it "can sync keys on a non-solaris host" do

          Command.should_receive( :new ).with( sync_cmd % "env PATH=/usr/gnu/bin:$PATH bash" ).exactly( 3 ).times

          setup_helper.sync_root_keys

        end

      end

    end
  end
end
