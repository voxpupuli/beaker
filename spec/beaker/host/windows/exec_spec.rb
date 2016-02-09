require 'spec_helper'

module Beaker
  describe Windows::Exec do
    class WindowsExecTest
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

    let (:opts)     { @opts || {} }
    let (:logger)   { double( 'logger' ).as_null_object }
    let (:instance) { WindowsExecTest.new(opts, logger) }

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
  end
end
