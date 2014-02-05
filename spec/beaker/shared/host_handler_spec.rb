require 'spec_helper'

module Beaker
  module Shared
    describe HostHandler do
      let( :host_handler )   { Beaker::Shared::HostHandler }
      let( :platform )       { @platform || 'unix' }
      let( :hosts )          { hosts = make_hosts( { :platform => platform } )
                               hosts[0][:roles] = ['agent']
                               hosts[1][:roles] = ['master', 'dashboard', 'agent', 'database']
                               hosts[2][:roles] = ['agent']
                               hosts }

      context 'get_domain_name' do

        it "can find the domain for a host" do
          host = make_host('name', { :stdout => "domain labs.lan d.labs.net dc1.labs.net labs.com\nnameserver 10.16.22.10\nnameserver 10.16.22.11" } )

          Command.should_receive( :new ).with( "cat /etc/resolv.conf" ).once

          expect( host_handler.get_domain_name( host ) ).to be === "labs.lan"

        end

        it "can find the search for a host" do
          host = make_host('name', { :stdout => "search labs.lan d.labs.net dc1.labs.net labs.com\nnameserver 10.16.22.10\nnameserver 10.16.22.11" } )

          Command.should_receive( :new ).with( "cat /etc/resolv.conf" ).once

          expect( host_handler.get_domain_name( host ) ).to be === "labs.lan"

        end
      end

      context "get_ip" do
        it "can exec the get_ip command" do
          host = make_host('name', { :stdout => "192.168.2.130\n" } )

          Command.should_receive( :new ).with( "ip a|awk '/global/{print$2}' | cut -d/ -f1 | head -1" ).once

          expect( host_handler.get_ip( host ) ).to be === "192.168.2.130"

        end

      end

      context "set_etc_hosts" do
        it "can set the /etc/hosts string on a host" do
          host = make_host('name', {})
          etc_hosts = "127.0.0.1  localhost\n192.168.2.130 pe-ubuntu-lucid\n192.168.2.128 pe-centos6\n192.168.2.131 pe-debian6"

          Command.should_receive( :new ).with( "echo '#{etc_hosts}' > /etc/hosts" ).once
          host.should_receive( :exec ).once

          host_handler.set_etc_hosts(host, etc_hosts)
        end

      end

      context "hosts_with_role" do
        it "can find the master in a set of hosts" do

          expect( host_handler.hosts_with_role( hosts, 'master' ) ).to be === [hosts[1]]

        end

        it "can find all agents in a set of hosts" do

          expect( host_handler.hosts_with_role( hosts, 'agent' ) ).to be === hosts

        end

        it "returns [] when no match is found in a set of hosts" do

          expect( host_handler.hosts_with_role( hosts, 'surprise' ) ).to be === []

        end

      end

      context "only_host_with_role" do
        it "can find the single master in a set of hosts" do

          expect( host_handler.only_host_with_role( hosts, 'master' ) ).to be === hosts[1]

        end

        it "throws an error when more than one host with matching role is found" do

          expect{ host_handler.only_host_with_role( hosts, 'agent' ) }.to raise_error(ArgumentError)

        end

        it "throws an error when no host is found matching the role" do

          expect{ host_handler.only_host_with_role( hosts, 'surprise' ) }.to raise_error(ArgumentError)

        end
      end

    end

  end
end
