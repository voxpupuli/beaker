require 'spec_helper'

module Beaker
  module Shared
    describe HostRoleParser do
      let( :host_handler )   { Beaker::Shared::HostRoleParser }
      let( :platform )       { @platform || 'unix' }
      let( :hosts )          { hosts = make_hosts( { :platform => platform } )
                               hosts[0][:roles] = ['agent']
                               hosts[1][:roles] = ['master', 'dashboard', 'agent', 'database']
                               hosts[2][:roles] = ['agent']
                               hosts }

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
