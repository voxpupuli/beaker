require 'spec_helper'

module Beaker
  describe Windows::Pkg do
    class WindowsPkgTest
      include Windows::Pkg

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

      def exec
        #noop
      end

    end

    let (:opts)     { @opts || {} }
    let (:logger)   { double( 'logger' ).as_null_object }
    let (:instance) { WindowsPkgTest.new(opts, logger) }

    describe '#install_package' do
      before :each do
        allow( instance ).to receive( :identify_windows_architecture )
      end

      context 'cygwin does not exist' do
        before :each do
          allow( instance ).to receive( :check_for_command ).and_return( false )
        end

        it 'curls the SSL URL for cygwin\'s installer' do
          expect( instance ).to receive( :execute ).with( /^curl.*https\:/  ).ordered
          allow(  instance ).to receive( :execute ).with( /^setup\-x86/     ).ordered
          instance.install_package( 'curl' )
        end

        it 'falls back to the non-SSL URL if that one fails' do
          allow(  instance ).to receive( :execute ).with( /^curl.*https\:/  ).and_raise( Beaker::Host::CommandFailure ).ordered
          expect( instance ).to receive( :execute ).with( /^curl.*http\:/   ).ordered
          allow(  instance ).to receive( :execute ).with( /^setup\-x86/     ).ordered
          instance.install_package( 'curl' )
        end
      end
    end

  end
end
