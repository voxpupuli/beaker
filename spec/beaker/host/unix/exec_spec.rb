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
  end
end
