require 'spec_helper'

module Beaker
  describe PSWindows::Exec do
    class PSWindowsExecTest
      include PSWindows::Exec

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
    let (:instance) { PSWindowsExecTest.new(opts, logger) }

    context "rm" do

      it "deletes" do
        path = '/path/to/delete'
        expect( instance ).to receive(:execute).with("del /s /q #{path}").and_return(0)
        expect( instance.rm_rf(path) ).to be === 0
      end
    end

    context 'mv' do
      let(:origin)      { '/origin/path/of/content' }
      let(:destination) { '/destination/path/of/content' }

      it 'rm first' do
        expect( instance ).to receive(:execute).with("del /s /q #{destination}").and_return(0)
        expect( instance ).to receive(:execute).with("move /y #{origin} #{destination}").and_return(0)
        expect( instance.mv(origin, destination) ).to be === 0

      end

      it 'does not rm' do
         expect( instance ).to receive(:execute).with("move /y #{origin} #{destination}").and_return(0)
         expect( instance.mv(origin, destination, false) ).to be === 0
      end
    end
  end
end
