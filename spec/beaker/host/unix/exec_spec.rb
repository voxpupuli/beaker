require 'spec_helper'

module Beaker
  describe Unix::Exec do
    class UnixExecTest
      include Unix::Exec

      def initialize(hash, logger)
        @hash = hash
        @logger = logger
      end

      def [](k)
        @hash[k]
      end

      def to_s
        "me"
      end

    end

    let (:opts)     { @opts || {} }
    let (:logger)   { double( 'logger' ).as_null_object }
    let (:instance) { UnixExecTest.new(opts, logger) }

    context "rm" do

      it "deletes" do
        path = '/path/to/delete'
        expect( instance ).to receive(:execute).with("rm -rf #{path}").and_return(0)
        expect( instance.rm_rf(path) ).to be === 0
      end
    end

    context 'mv' do
      let(:origin)      { '/origin/path/of/content' }
      let(:destination) { '/destination/path/of/content' }

      it 'rm first' do
        expect( instance ).to receive(:execute).with("rm -rf #{destination}").and_return(0)
        expect( instance ).to receive(:execute).with("mv #{origin} #{destination}").and_return(0)
        expect( instance.mv(origin, destination) ).to be === 0

      end

      it 'does not rm' do
         expect( instance ).to receive(:execute).with("mv #{origin} #{destination}").and_return(0)
         expect( instance.mv(origin, destination, false) ).to be === 0
      end
    end

    describe '#environment_string' do
      let(:host) { {'pathseparator' => ':'} }

      it 'returns a blank string if theres no env' do
        expect( instance ).to receive( :is_powershell? ).never
        expect( instance.environment_string( {} ) ).to be == ''
      end

      it 'takes an env hash with var_name/value pairs' do
        expect( instance.environment_string( {:HOME => '/'} ) ).
          to be == "env HOME=\"/\""
      end

      it 'takes an env hash with var_name/value[Array] pairs' do
        expect( instance.environment_string( {:LD_PATH => ['/', '/tmp']}) ).
          to be == "env LD_PATH=\"/:/tmp\""
      end
    end

    describe '#ssh_permit_user_environment' do
      it 'raises an error on unsupported platforms' do
        opts['platform'] = 'notarealthing01-parts-arch'
        expect {
          instance.ssh_permit_user_environment
        }.to raise_error( ArgumentError, /#{opts['platform']}/ )
      end
    end

    describe '#ssh_service_restart' do
      it 'raises an error on unsupported platforms' do
        opts['platform'] = 'notarealthing02-parts-arch'
        expect {
          instance.ssh_service_restart
        }.to raise_error( ArgumentError, /#{opts['platform']}/ )
      end
    end

    describe '#prepend_commands' do

      it 'returns the pc parameter unchanged for non-cisco platforms' do
        allow( instance ).to receive( :[] ).with( :platform ).and_return( 'notcisco' )
        answer_prepend_commands = 'pc_param_unchanged_13579'
        answer_test = instance.prepend_commands( 'fake_cmd', answer_prepend_commands )
        expect( answer_test ).to be === answer_prepend_commands
      end

      context 'for cisco-5' do

        before :each do
          allow( instance ).to receive( :[] ).with( :platform ).and_return( 'cisco-5' )
        end

        it 'ends with the :vrf host parameter' do
          vrf_answer = 'vrf_answer_135246'
          allow( instance ).to receive( :[] ).with( :vrf ).and_return( vrf_answer )
          answer_test = instance.prepend_commands( 'fake_command' )
          expect( answer_test ).to match( /#{vrf_answer}$/ )
        end

        it 'begins with sourcing the /etc/profile script' do
          allow( instance ).to receive( :[] ).with( :vrf ).and_return( nil )
          answer_test = instance.prepend_commands( 'fake_command' )
          expect( answer_test ).to match( /^#{Regexp.escape('source /etc/profile; ')}/ )
        end

        it 'uses sudo at the beginning of the actual command to execute' do
          allow( instance ).to receive( :[] ).with( :vrf ).and_return( nil )
          answer_test = instance.prepend_commands( 'fake_command' )
          command_start_index = answer_test.index( '; ' ) + 2
          command_actual = answer_test[command_start_index, answer_test.length - command_start_index]
          expect( command_actual ).to match( /^sudo / )
        end

        it 'guards against "vsh" usage (only scenario we dont want prefixing)' do
          allow( instance ).to receive( :[] ).with( :vrf ).and_return( nil )
          answer_prepend_commands = 'pc_param_unchanged_13584'
          answer_test = instance.prepend_commands( 'fake/vsh/command', answer_prepend_commands )
          expect( answer_test ).to be === answer_prepend_commands
        end
      end
    end
  end
end
