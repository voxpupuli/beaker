require 'spec_helper'

module Beaker
  describe Unix::File do
    class UnixFileTest
      include Unix::File

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

      attr_reader :logger
    end

    let(:opts)     { @opts || {} }
    let(:logger)   { double('logger').as_null_object }
    let(:platform) do
      if @platform
        { 'platform' => Beaker::Platform.new(@platform) }
      else
        { 'platform' => Beaker::Platform.new('osx-10.9-x86_64') }
      end
    end
    let(:instance) { UnixFileTest.new(opts.merge(platform), logger) }

    describe '#noask_file_text' do
      it 'errors on non-solaris platforms' do
        @platform = 'debian-12-x86_64'
        expect do
          instance.noask_file_text
        end.to raise_error(ArgumentError, /^noask\ file\ text\ unknown/)
      end

      it 'errors on solaris versions other than 10' do
        @platform = 'solaris-11-x86_64'
        expect do
          instance.noask_file_text
        end.to raise_error(ArgumentError, /^noask\ file\ text\ unknown/)
      end

      it 'returns the noask file correctly for solaris 10' do
        @platform = 'solaris-10-x86_64'
        text = instance.noask_file_text
        expect(text).to match(/instance\=overwrite/)
        expect(text).to match(/space\=quit/)
        expect(text).to match(/basedir\=default/)
      end
    end

    describe '#chown' do
      let(:user) { 'someuser' }
      let(:path) { '/path/to/chown/on' }

      it 'calls the system method' do
        expect(instance).to receive(:execute).with("chown #{user} #{path}").and_return(0)
        expect(instance.chown(user, path)).to be === 0
      end

      it 'passes -R if recursive' do
        expect(instance).to receive(:execute).with("chown \-R #{user} #{path}")
        instance.chown(user, path, true)
      end
    end

    describe '#cat' do
      let(:path) { '/path/to/cat/on' }

      it 'calls cat for path' do
        expect(instance).to receive(:execute).with("cat #{path}").and_return(0)
        expect(instance.cat(path)).to be === 0
      end
    end

    describe '#chmod' do
      context 'not recursive' do
        it 'calls execute with chmod' do
          path = '/path/to/file'
          mod = '+x'

          expect(instance).to receive(:execute).with("chmod #{mod} #{path}")
          instance.chmod(mod, path)
        end
      end

      context 'recursive' do
        it 'calls execute with chmod' do
          path = '/path/to/file'
          mod = '+x'

          expect(instance).to receive(:execute).with("chmod -R #{mod} #{path}")
          instance.chmod(mod, path, true)
        end
      end
    end

    describe '#chgrp' do
      let(:group) { 'somegroup' }
      let(:path) { '/path/to/chgrp/on' }

      it 'calls the system method' do
        expect(instance).to receive(:execute).with("chgrp #{group} #{path}").and_return(0)
        expect(instance.chgrp(group, path)).to be === 0
      end

      it 'passes -R if recursive' do
        expect(instance).to receive(:execute).with("chgrp \-R #{group} #{path}")
        instance.chgrp(group, path, true)
      end
    end

    describe '#ls_ld' do
      let(:path) { '/path/to/ls_ld' }

      it 'calls the system method' do
        expect(instance).to receive(:execute).with("ls -ld #{path}").and_return(0)
        expect(instance.ls_ld(path)).to be === 0
      end
    end
  end
end
