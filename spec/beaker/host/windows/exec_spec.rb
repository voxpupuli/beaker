require 'spec_helper'

module Beaker
  describe Windows::Exec do
    class WindowsExecTest
      include Unix::Exec
      include Windows::Exec

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

    let(:opts)     { @opts || {} }
    let(:logger)   { double( 'logger' ).as_null_object }
    let(:instance) { WindowsExecTest.new(opts, logger) }

    describe '#prepend_commands' do
      it 'sets spacing correctly if both parts are defined' do
        allow( instance ).to receive( :is_cygwin? ).and_return( true )
        command_str = instance.prepend_commands( 'command', 'pants', { :cmd_exe => true } )
        expect( command_str ).to be === 'cmd.exe /c pants'
      end

      it 'sets spacing empty if one is not supplied' do
        allow( instance ).to receive( :is_cygwin? ).and_return( true )
        command_str = instance.prepend_commands( 'command', 'pants' )
        expect( command_str ).to be === 'pants'
      end

      it 'does not use cmd.exe by default' do
        allow( instance ).to receive( :is_cygwin? ).and_return( true )
        command_str = instance.prepend_commands( 'pants' )
        expect( command_str ).not_to match( /cmd\.exe/ )
      end
    end

    describe '#selinux_enabled?' do
      it 'does not call selinuxenabled' do
        expect(Beaker::Command).not_to receive(:new).with("sudo selinuxenabled")
        expect(instance).not_to receive(:exec).with(0, :accept_all_exit_codes => true)
        expect(instance.selinux_enabled?).to be === false
      end
    end

    describe '#reboot' do
      it 'invokes the correct command on the host' do
        expect( Beaker::Command ).to receive( :new ).with( /^shutdown \/f \/r \/t 0 \/d p:4:1 \/c "Beaker::Host reboot command issued"/ ).and_return( :foo )
        expect( instance ).to receive( :exec ).with( :foo, :reset_connection => true )
        expect( instance ).to receive( :sleep )
        instance.reboot
      end
    end

    describe '#cygwin_installed?' do
      let(:response) { double( 'response' ) }

      it 'uses cygcheck to see if cygwin is installed' do
        expect( Beaker::Command ).to receive(:new).with("cygcheck --check-setup cygwin").and_return(:foo)
        expect( instance ).to receive( :exec ).with(:foo, :accept_all_exit_codes => true).and_return(response)
        expect( response ).to receive(:stdout).and_return('cygwin OK')
        expect(instance.cygwin_installed?).to eq(true)
      end

      it 'returns false when unable to find matching text' do
        expect( Beaker::Command ).to receive(:new).with("cygcheck --check-setup cygwin").and_return(:foo)
        expect( instance ).to receive( :exec ).with(:foo, :accept_all_exit_codes => true).and_return(response)
        expect( response ).to receive(:stdout).and_return('No matching text')
        expect(instance.cygwin_installed?).to eq(false)
      end
    end

    context 'mv' do
      let(:origin)      { '/origin/path/of/content' }
      let(:destination) { '/destination/path/of/content' }

      it 'rm first' do
        expect( instance ).to receive(:execute).with("rm -rf #{destination}").and_return(0)
        expect( instance ).to receive(:execute).with("mv \"#{origin}\" \"#{destination}\"").and_return(0)
        expect( instance.mv(origin, destination) ).to be === 0

      end

      it 'does not rm' do
         expect( instance ).to receive(:execute).with("mv \"#{origin}\" \"#{destination}\"").and_return(0)
         expect( instance.mv(origin, destination, false) ).to be === 0
      end
    end

    context 'mkdir_p' do
      let(:path) { '~/.ssh' }
      let(:result) do
        result = Beaker::Result.new(nil, '')
        result.exit_code = 0
        result
      end

      it 'accepts Pathname arguments' do
        expect( instance ).to receive(:exec).with(having_attributes(command: "mkdir -p #{path}"), anything).and_return(result)
        expect(instance.mkdir_p(Pathname.new(path))).to eq(true)
      end

      it 'omits quotes if the path starts with ~ and does not contain spaces' do
        expect( instance ).to receive(:exec).with(having_attributes(command: "mkdir -p #{path}"), anything).and_return(result)
        expect(instance.mkdir_p(path)).to eq(true)
      end

      it 'double quotes paths containing spaces' do
        expect( instance ).to receive(:exec).with(having_attributes(command: "mkdir -p \"~/.foo bar\""), anything).and_return(result)
        expect(instance.mkdir_p("~/.foo bar")).to eq(true)
      end

      it 'returns false if the command failed' do
        result.exit_code = 1
        expect( instance ).to receive(:exec).with(having_attributes(command: "mkdir -p #{path}"), anything).and_return(result)
        expect(instance.mkdir_p(path)).to eq(false)
      end
    end
  end
end
