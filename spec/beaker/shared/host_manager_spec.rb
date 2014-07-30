require 'spec_helper'

module Beaker
  module Shared
    describe HostManager do
      let( :host_handler )   { Beaker::Shared::HostManager }
      let( :spec_block )     { Proc.new { |arr| arr } }
      let( :platform )       { @platform || 'unix' }
      let( :role0 )          { "role0" }
      let( :role1 )          { :role1 }
      let( :role2 )          { :role2 }
      let( :hosts )          { hosts = make_hosts( { :platform => platform } )
                               hosts[0][:roles] = ['agent', role0]
                               hosts[1][:roles] = ['master', 'dashboard', 'agent', 'database', role1]
                               hosts[2][:roles] = ['agent', role2]
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

      context "run_block_on" do
        it "can execute a block against hosts identified by a string" do
          myhosts = host_handler.run_block_on( hosts, role0 ) do |hosts|
            hosts
          end
          expect( myhosts ).to be  === hosts[0]

        end

        it "can execute a block against hosts identified by a hostname" do
          myhosts = host_handler.run_block_on( hosts, hosts[0].name ) do |hosts|
            hosts
          end
          expect( myhosts ).to be  === hosts[0]

        end

        it "can execute a block against an array of hosts" do
          myhosts = host_handler.run_block_on( hosts ) do |hosts|
            hosts
          end
          expect( myhosts ).to be  === hosts

        end

      end

    end

  end
end
