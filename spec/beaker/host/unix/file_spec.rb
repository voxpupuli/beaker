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

    describe '#repo_type' do
      %w[amazon centos redhat].each do |platform|
        it "returns correctly for platform '#{platform}'" do
          @platform = "#{platform}-5-x86_64"
          expect(instance.repo_type).to be === 'rpm'
        end
      end

      it 'returns correctly for debian-based platforms' do
        @platform = 'debian-6-x86_64'
        expect(instance.repo_type).to be === 'deb'
      end

      it 'errors for all other platform types' do
        @platform = 'eos-4-x86_64'
        expect do
          instance.repo_type
        end.to raise_error(ArgumentError, /repo\ type\ not\ known/)
      end
    end

    describe '#package_config_dir' do
      %w[amazon centos redhat].each do |platform|
        it "returns correctly for platform '#{platform}'" do
          @platform = "#{platform}-5-x86_64"
          expect(instance.package_config_dir).to be === '/etc/yum.repos.d/'
        end
      end

      it 'returns correctly for debian-based platforms' do
        @platform = 'debian-6-x86_64'
        expect(instance.package_config_dir).to be === '/etc/apt/sources.list.d'
      end

      it 'returns correctly for sles-based platforms' do
        @platform = 'sles-12-x86_64'
        expect(instance.package_config_dir).to be === '/etc/zypp/repos.d/'
      end

      it 'returns correctly for opensuse-based platforms' do
        @platform = 'opensuse-15-x86_64'
        expect(instance.package_config_dir).to be === '/etc/zypp/repos.d/'
      end

      it 'errors for all other platform types' do
        @platform = 'eos-4-x86_64'
        expect do
          instance.package_config_dir
        end.to raise_error(ArgumentError, /package\ config\ dir\ unknown/)
      end
    end

    describe '#repo_filename' do
      %w[centos redhat].each do |platform|
        it "sets the el portion correctly for '#{platform}'" do
          @platform = "#{platform}-5-x86_64"
          allow(instance).to receive(:is_pe?).and_return(false)
          filename = instance.repo_filename('pkg_name', 'pkg_version7')
          expect(filename).to match(/sion7\-el\-/)
        end
      end

      it 'sets the sles portion correctly for sles platforms' do
        @platform = 'sles-11-x86_64'
        allow(instance).to receive(:is_pe?).and_return(false)
        filename = instance.repo_filename('pkg_name', 'pkg_version7')
        expect(filename).to match(/sion7\-sles\-/)
      end

      it 'sets the opensuse portion correctly for opensuse platforms' do
        @platform = 'opensuse-15-x86_64'
        allow(instance).to receive(:is_pe?).and_return(false)
        filename = instance.repo_filename('pkg_name', 'pkg_version7')
        expect(filename).to match(/sion7\-opensuse\-/)
      end

      it 'builds the filename correctly for el-based platforms' do
        @platform = 'el-21-x86_64'
        allow(instance).to receive(:is_pe?).and_return(false)
        filename = instance.repo_filename('pkg_name', 'pkg_version8')
        correct = 'pl-pkg_name-pkg_version8-el-21-x86_64.repo'
        expect(filename).to be === correct
      end

      it 'builds the filename correctly for redhatfips platforms' do
        @platform = 'el-7-x86_64'
        allow(instance).to receive(:[]).with('platform') { platform['platform'] }
        expect(instance).to receive(:[]).with('packaging_platform').and_return('redhatfips-7-x86_64')
        filename = instance.repo_filename('pkg_name', 'pkg_version')
        correct = 'pl-pkg_name-pkg_version-redhatfips-7-x86_64.repo'
        expect(filename).to be === correct
      end

      it 'adds in the PE portion of the filename correctly for el-based PE hosts' do
        @platform = 'el-21-x86_64'
        allow(instance).to receive(:is_pe?).and_return(true)
        filename = instance.repo_filename('pkg_name', 'pkg_version9')
        correct = 'pl-pkg_name-pkg_version9-el-21-x86_64.repo'
        expect(filename).to be === correct
      end

      it 'builds the filename correctly for debian-based platforms' do
        @platform = 'debian-8-x86_64'
        filename = instance.repo_filename('pkg_name', 'pkg_version10')
        correct = 'pl-pkg_name-pkg_version10-jessie.list'
        expect(filename).to be === correct
      end

      it 'uses the variant for the codename on the cumulus platform' do
        @platform = 'cumulus-2.5-x86_64'
        filename = instance.repo_filename('pkg_name', 'pkg_version11')
        correct = 'pl-pkg_name-pkg_version11-cumulus.list'
        expect(filename).to be === correct
      end

      it 'adds wrlinux to variant on cisco platforms' do
        @platform = 'cisco_nexus-7-x86_64'
        allow(instance).to receive(:is_pe?).and_return(false)
        filename = instance.repo_filename('pkg_name', 'pkg_version12')
        expect(filename).to match(/sion12\-cisco\-wrlinux\-/)
      end

      it 'errors for non-el or debian-based platforms' do
        @platform = 'freebsd-22-x86_64'
        expect do
          instance.repo_filename('pkg_name', 'pkg_version')
        end.to raise_error(ArgumentError, /repo\ filename\ pattern\ not\ known/)
      end
    end

    describe '#noask_file_text' do
      it 'errors on non-solaris platforms' do
        @platform = 'cumulus-4000-x86_64'
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
