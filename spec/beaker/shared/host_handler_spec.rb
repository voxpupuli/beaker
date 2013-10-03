require 'spec_helper'

module Beaker
  module Shared
    describe HostHandler do
      let( :logger ) { double( 'logger' ).as_null_object }
      let( :defaults ) { Beaker::Options::OptionsHash.new.merge( { :logger => logger} ) }
      let( :options ) { @options ? defaults.merge( @options ) : defaults}

      let( :host_handler ) { Beaker::Shared::HostHandler }

      let( :vms ) { ['vm1', 'vm2', 'vm3'] }
      let( :snaps )  { ['snapshot1', 'snapshot2', 'snapshot3'] }
      let( :roles_def ) { [ ['agent'], ['master', 'dashboard', 'agent', 'database'], ['agent'] ] }

      def make_host name, snap, roles, platform
        opts = Beaker::Options::OptionsHash.new.merge( { :logger => logger, 
                                                         'HOSTS' => { name => 
                                                                      { 'platform' => platform, 
                                                                        :snapshot => snap, 
                                                                        :roles => roles } 
                                                                    } } )
        Host.create( name, opts )
      end

      def make_hosts names, snaps, roles_def, platform = 'unix'
        hosts = []
        names.zip(snaps, roles_def).each do |vm, snap, roles|
          hosts << make_host( vm, snap, roles, platform )
        end
        hosts
      end 


      context 'get_domain_name' do

        it "can find the domain for a host" do
          host = make_host('name', 'snap', ['agent'], 'unix')

          Command.should_receive( :new ).with( "cat /etc/resolv.conf" ).exactly( 1 ).times
          result = mock( 'result' )
          result.stub( :stdout ).and_return( "domain labs.lan d.labs.net dc1.labs.net labs.com\nnameserver 10.16.22.10\nnameserver 10.16.22.11" )
          host.should_receive( :exec ).exactly( 1 ).times.and_return( result )

          expect( host_handler.get_domain_name( host ) ).to be === "labs.lan"

        end

        it "can find the search for a host" do
          host = make_host('name', 'snap', ['agent'], 'unix')

          Command.should_receive( :new ).with( "cat /etc/resolv.conf" ).exactly( 1 ).times
          result = mock( 'result' )
          result.stub( :stdout ).and_return( "search labs.lan d.labs.net dc1.labs.net labs.com\nnameserver 10.16.22.10\nnameserver 10.16.22.11" )
          host.should_receive( :exec ).exactly( 1 ).times.and_return( result )

          expect( host_handler.get_domain_name( host ) ).to be === "labs.lan"

        end
      end

      context "get_ip" do
        it "can exec the get_ip command" do
          host = make_host('name', 'snap', ['agent'], 'unix')

          Command.should_receive( :new ).with( "ip a|awk '/g/{print$2}' | cut -d/ -f1 | head -1" ).exactly( 1 ).times
          result = mock( 'result' )
          result.stub( :stdout ).and_return( "192.168.2.130\n" )
          host.should_receive( :exec ).exactly( 1 ).times.and_return( result )

          expect( host_handler.get_ip( host ) ).to be === "192.168.2.130"

        end

      end

      context "set_etc_hosts" do
        it "can set the /etc/hosts string on a host" do
          host = make_host('name', 'snap', ['agent'], 'unix')
          etc_hosts = "127.0.0.1  localhost\n192.168.2.130 pe-ubuntu-lucid\n192.168.2.128 pe-centos6\n192.168.2.131 pe-debian6"

          Command.should_receive( :new ).with( "echo '#{etc_hosts}' > /etc/hosts" ).exactly( 1 ).times
          host.should_receive( :exec ).exactly( 1 ).times

          host_handler.set_etc_hosts(host, etc_hosts)
        end

      end

      context "hosts_with_role" do
        it "can find the master in a set of hosts" do
          hosts = make_hosts( vms, snaps, roles_def )

          expect( host_handler.hosts_with_role( hosts, 'master' ) ).to be === [hosts[1]]

        end

        it "can find all agents in a set of hosts" do
          hosts = make_hosts( vms, snaps, roles_def )

          expect( host_handler.hosts_with_role( hosts, 'agent' ) ).to be === hosts

        end

        it "returns [] when no match is found in a set of hosts" do
          hosts = make_hosts( vms, snaps, roles_def )

          expect( host_handler.hosts_with_role( hosts, 'surprise' ) ).to be === []

        end

      end

      context "only_host_with_role" do
        it "can find the single master in a set of hosts" do
          hosts = make_hosts( vms, snaps, roles_def )

          expect( host_handler.only_host_with_role( hosts, 'master' ) ).to be === hosts[1]

        end

        it "throws an error when more than one host with matching role is found" do
          hosts = make_hosts( vms, snaps, roles_def )

          expect{ host_handler.only_host_with_role( hosts, 'agent' ) }.to raise_error(ArgumentError)

        end

        it "throws an error when no host is found matching the role" do
          hosts = make_hosts( vms, snaps, roles_def )

          expect{ host_handler.only_host_with_role( hosts, 'surprise' ) }.to raise_error(ArgumentError)

        end
      end

    end

  end
end
