require 'spec_helper'

module Beaker
  describe Mac::Exec do
    class MacExecTest
      include Mac::Exec

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
    let(:instance) { MacExecTest.new(opts, logger) }

    describe '#selinux_enabled?' do
      it 'does not call selinuxenabled' do
        expect(Beaker::Command).not_to receive(:new).with("sudo selinuxenabled")
        expect(instance).not_to receive(:exec).with(0, :accept_all_exit_codes => true)
        expect(instance.selinux_enabled?).to be === false
      end
    end

    describe '#modified_at' do
      it 'calls execute with touch and timestamp' do
        time = '190101010000'
        path = '/path/to/file'
        expect( instance ).to receive(:execute).with("touch -mt #{time} #{path}").and_return(0)

        instance.modified_at(path, time)
      end
    end
  end
end
