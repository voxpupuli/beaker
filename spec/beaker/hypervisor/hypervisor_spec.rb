require 'spec_helper'

module Beaker
  describe Hypervisor do
    let( :hosts ) { make_hosts( { :platform => 'el-5' } ) }

    describe "#create" do
      let( :hypervisor ) { described_class }

      it "includes custom hypervisor and call set_ssh_connection_preference" do
        allow(hypervisor).to receive(:set_ssh_connection_preference).with([], hypervisor)
        expect{ hypervisor.create('custom_hypervisor', [], make_opts() )}.to raise_error(LoadError, "cannot load such file -- beaker/hypervisor/custom_hypervisor")
      end

      it "sets ssh connection preference if connection_preference method is not overwritten" do
        hypervisor.create('none', hosts, make_opts())
        expect(hosts[0][:ssh_connection_preference]).to eq([:ip,:vmhostname,:hostname])
      end

      it "concats overriding connection_preference array with the default connection_preference" do
        allow(hypervisor).to receive(:connection_preference).and_return([:my,:invalid,:method_name])
        hypervisor.set_ssh_connection_preference(hosts, hypervisor)
        expect(hosts[0][:ssh_connection_preference]).to eq([:my,:invalid,:method_name,:ip,:vmhostname,:hostname])
      end

      it "removes unique elements from concated array while preserving order of overriding methods" do
        allow(hypervisor).to receive(:connection_preference).and_return([:my,:ip,:vmhostname,:method_name])
        hypervisor.set_ssh_connection_preference(hosts, hypervisor)
        expect(hosts[0][:ssh_connection_preference]).to eq([:my,:ip,:vmhostname,:method_name,:hostname])
      end

      it "gives highest precedence to preference specified in host file followed by hypervisor" do
        hosts[0].options[:ssh_preference] = [:set, :in, :hostfile]
        hypervisor.create('none', hosts, make_opts())
        allow(hypervisor).to receive(:connection_preference).and_return([:hypervisor, :pref])
        hypervisor.set_ssh_connection_preference(hosts, hypervisor)
        expect(hosts[0][:ssh_connection_preference]).to eq([:set, :in, :hostfile, :hypervisor, :pref, :ip, :vmhostname, :hostname])
      end

    end

    describe "#configure" do
      let( :options ) { make_opts.merge({ 'logger' => double().as_null_object }) }
      let( :hypervisor ) { described_class.new( hosts, options ) }

      context 'if :timesync option set true on host' do
        it 'does call timesync for host' do
          hosts[0].options[:timesync] = true
          allow( hypervisor ).to receive( :set_env )
          expect( hypervisor ).to receive( :timesync ).once
          hypervisor.configure
        end

        it 'catches signal exceptions and returns stack trace' do
          logger = double()
          hosts[0].options[:timesync] = true
          allow( logger ).to receive( :error )
          allow( logger ).to receive( :pretty_backtrace ).and_return("multiline\nstring")
          hypervisor.instance_variable_set(:@logger, logger)
          allow(Beaker::Command).to receive(:new).and_raise(SignalException.new('SIGTERM'))
          expect{ hypervisor.configure }.to raise_error(SignalException)
        end
      end

      context 'if :timesync option set true but false on host' do
        it 'does not call timesync for host' do
          options[:timesync] = true
          hosts[0].options[:timesync] = false
          allow( hypervisor ).to receive( :set_env )
          expect( hypervisor ).not_to receive( :timesync )
          hypervisor.configure
        end
      end

      context 'if :run_in_parallel option includes configure' do
        it 'timesync is run in parallel' do
          InParallel::InParallelExecutor.logger = logger
          # Need to deactivate FakeFS since the child processes write STDOUT to file.
          FakeFS.deactivate!
          hosts[0].options[:timesync] = true
          hosts[1].options[:timesync] = true
          hosts[2].options[:timesync] = true
          options[:run_in_parallel] = ['configure']
          allow( hypervisor ).to receive( :set_env )
          # This will only get hit if forking processes is supported and at least 2 items are being submitted to run in parallel
          expect( InParallel::InParallelExecutor ).to receive(:_execute_in_parallel).with(any_args).and_call_original.exactly(3).times
          hypervisor.configure
        end
      end

      context "if :disable_iptables option set false" do
        it "does not call disable_iptables" do
          options[:disable_iptables] = false
          allow( hypervisor ).to receive( :set_env )
          expect( hypervisor ).not_to receive( :disable_iptables )
          hypervisor.configure
        end
      end

      context "if :disable_iptables option set true" do
        it "calls disable_iptables once" do
          options[:disable_iptables] = true
          allow( hypervisor ).to receive( :set_env )
          expect( hypervisor ).to receive( :disable_iptables ).once
          hypervisor.configure
        end
      end

      context "if :disable_updates option set true" do
        it "calls disable_updates" do
          options[:disable_updates] = true
          allow( hypervisor ).to receive( :set_env )
          expect( hypervisor ).to receive( :disable_updates ).once
          hypervisor.configure
        end
      end

      context "if :disable_updates option set false" do
        it "does not call disable_updates_puppetlabs_com" do
          options[:disable_updates] = false
          allow( hypervisor ).to receive( :set_env )
          expect( hypervisor ).not_to receive( :disable_updates )
          hypervisor.configure
        end
      end

      context 'if :configure option set false' do
        it 'does not make any configure calls' do
          options[:configure]         = false
          options[:timesync]          = true
          options[:root_keys]         = true
          options[:add_el_extras]     = true
          options[:disable_iptables]  = true
          options[:host_name_prefix]  = "test-"
          expect( hypervisor ).not_to receive( :timesync )
          expect( hypervisor ).not_to receive( :sync_root_keys )
          expect( hypervisor ).not_to receive( :add_el_extras )
          expect( hypervisor ).not_to receive( :disable_iptables )
          expect( hypervisor ).not_to receive( :set_env )
          expect( hypervisor ).not_to receive( :host_name_prefix )
          hypervisor.configure
        end
      end

      context 'if :configure option set true' do
        it 'does call set_env' do
          options[:configure] = true
          expect( hypervisor ).to receive( :set_env ).once
          hypervisor.configure
        end
      end

      context 'if :host_name_prefix is set' do
        it "generates hostname with prefix" do
          prefix = "testing-prefix-to-test-"
          options[:host_name_prefix] = prefix
	  expect( hypervisor.generate_host_name().start_with?(prefix) ).to be true
	  expect( hypervisor.generate_host_name().length - prefix.length >= 15 ).to be true
        end
      end

    end

  end
end
