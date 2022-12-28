require 'spec_helper'

module Beaker
  module Shared

    config = RSpec::Mocks.configuration

    config.patch_marshal_to_support_partial_doubles = true

    describe HostManager do
      # The logger double as nil object doesn't work with marshal.load and marshal.unload needed for run_in_parallel.
      let( :logger )         { double('logger') }
      let( :host_handler )   { described_class }
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

      describe "#hosts_with_name" do

        it "can identify the host by name" do

            expect( host_handler.hosts_with_name( hosts, 'vm1' )).to be === [hosts[0]]

        end

        it "can identify the host by vmhostname" do

            hosts[0][:vmhostname] = 'myname.whatever'

            expect( host_handler.hosts_with_name( hosts, 'myname.whatever' )).to be === [hosts[0]]

        end

        it "can identify the host by ip" do

            hosts[0][:ip] = '0.0.0.0'

            expect( host_handler.hosts_with_name( hosts, '0.0.0.0' )).to be === [hosts[0]]

        end

        it "returns [] when no match is found in a set of hosts" do

            hosts[0][:ip] = '0.0.0.0'
            hosts[0][:vmhostname] = 'myname.whatever'

            expect( host_handler.hosts_with_name( hosts, 'surprise' )).to be === []

        end



      end

      describe "#hosts_with_role" do
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

      describe "#only_host_with_role" do
        it "can find the single master in a set of hosts" do

          expect( host_handler.only_host_with_role( hosts, 'master' ) ).to be === hosts[1]

        end

        it "throws an error when more than one host with matching role is found" do

          expect{ host_handler.only_host_with_role( hosts, 'agent' ) }.to raise_error(ArgumentError)

        end

        it "throws an error when no host is found matching the role" do

          expect{ host_handler.only_host_with_role( hosts, 'surprise' ) }.to raise_error(ArgumentError)

        end

        it "throws an error when role = nil" do
          expect{ host_handler.find_at_most_one_host_with_role( hosts, nil ) }.to raise_error(ArgumentError)
        end
      end

      describe "#find_at_most_one_host_with_role" do
        it "can find the single master in a set of hosts" do

          expect( host_handler.find_at_most_one_host_with_role( hosts, 'master' ) ).to be === hosts[1]

        end

        it "throws an error when more than one host with matching role is found" do

          expect{ host_handler.find_at_most_one_host_with_role( hosts, 'agent' ) }.to raise_error(ArgumentError)

        end

        it "returns nil when no host is found matching the role" do

          expect( host_handler.find_at_most_one_host_with_role( hosts, 'surprise' ) ).to be_nil

        end

        it "throws an error when role = nil" do
          expect{ host_handler.find_at_most_one_host_with_role( hosts, nil ) }.to raise_error(ArgumentError)
        end
      end

      describe "#run_block_on" do
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

        it "can execute a block against an array of hosts in parallel" do
          InParallel::InParallelExecutor.logger = Logger.new(STDOUT)
          FakeFS.deactivate!

          expect( InParallel::InParallelExecutor ).to receive(:_execute_in_parallel).with(any_args).and_call_original.exactly(3).times

          myhosts = host_handler.run_block_on( hosts, nil, { :run_in_parallel => true } ) do |host|
            # kind of hacky workaround to remove logger which contains a singleton method injected by rspec

            host.instance_eval("remove_instance_variable(:@logger)")
            host
          end

          # After marshal load and marshal unload, the logger option (an rspec double) is no longer 'equal' to the original.
          # Array of results can be in different order.
          new_host = myhosts.find{ |host| host.name == hosts[0].name}
          hosts[0].options.each { |option|
            expect(option[1]).to eq(new_host.options[option[0]]) unless option[0] == :logger
          }
        end

        it "will ignore run_in_parallel global option" do
          myhosts = host_handler.run_block_on( hosts, nil, { :run_in_parallel => [] } ) do |host|
            host
          end
          expect( InParallel::InParallelExecutor ).not_to receive(:_execute_in_parallel).with(any_args)
          expect(myhosts).to eq(hosts)
        end

        it "does not run in parallel if there is only 1 host in the array" do
          myhosts = host_handler.run_block_on( [hosts[0]], nil, { :run_in_parallel => true } ) do |host|
            puts host
            host
          end

          expect( myhosts ).to be  === [hosts[0]]
        end

        it "receives an ArgumentError on empty host" do
          expect { host_handler.run_block_on( [], role0 ) }.to raise_error(ArgumentError)
        end

      end

    end

  end
end
