require 'spec_helper'

module Beaker
  describe FreeBSD::Exec do
    class FreeBSDExecTest
      include FreeBSD::Exec

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
    let(:instance) { FreeBSDExecTest.new(opts, logger) }

    context "echo_to_file" do

      it "runs the correct echo command" do
        expect( Beaker::Command ).to receive(:new).with('printf "127.0.0.1\tlocalhost localhost.localdomain\n10.255.39.23\tfreebsd-10-x64\n" > /etc/hosts').and_return('')
        expect( instance ).to receive(:exec).with('').and_return(generate_result("hello", {:exit_code => 0}))
        instance.echo_to_file('127.0.0.1\tlocalhost localhost.localdomain\n10.255.39.23\tfreebsd-10-x64\n', '/etc/hosts')
      end

    end
  end
end

