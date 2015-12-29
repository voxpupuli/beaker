require 'spec_helper'

module Beaker
  describe FreeBSD::Pkg do
    class FreeBSDPkgTest
      include FreeBSD::Pkg

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
    let (:instance) { FreeBSDPkgTest.new(opts, logger) }

    context "install_package" do

      it "runs the correct install command" do
        expect( Beaker::Command ).to receive(:new).with('pkg install -y rsync', [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
        expect( instance ).to receive(:exec).with('', {}).and_return(generate_result("hello", {:exit_code => 0}))
        instance.install_package('rsync')
      end

    end

    context "check_for_package" do

      it "runs the correct checking command" do
        expect( Beaker::Command ).to receive(:new).with('pkg info rsync', [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
        expect( instance ).to receive(:exec).with('', {}).and_return(generate_result("hello", {:exit_code => 0}))
        instance.check_for_package('rsync')
      end

    end

  end
end

