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

      def logger
        @logger
      end

    end

    let (:opts)     { @opts || {} }
    let (:logger)   { double( 'logger' ).as_null_object }
    let (:platform) {
      if @platform
        { 'platform' => Beaker::Platform.new( @platform) }
      else
        { 'platform' => Beaker::Platform.new( 'osx-10.9-x86_64' ) }
      end
    }
    let (:instance) { UnixFileTest.new(opts.merge(platform), logger) }

    describe '#repo_type' do

      it 'returns correctly for el-based platforms' do
        @platform = 'centos-6-x86_64'
        expect( instance.repo_type ).to be === 'rpm'
      end

      it 'returns correctly for debian-based platforms' do
        @platform = 'debian-6-x86_64'
        expect( instance.repo_type ).to be === 'deb'
      end

      it 'errors for all other platform types' do
        @platform = 'eos-4-x86_64'
        expect {
          instance.repo_type
        }.to raise_error( ArgumentError, /repo\ type\ not\ known/ )
      end
    end

    describe '#package_config_dir' do

      it 'returns correctly for el-based platforms' do
        @platform = 'centos-6-x86_64'
        expect( instance.package_config_dir ).to be === '/etc/yum.repos.d/'
      end

      it 'returns correctly for debian-based platforms' do
        @platform = 'debian-6-x86_64'
        expect( instance.package_config_dir ).to be === '/etc/apt/sources.list.d'
      end

      it 'errors for all other platform types' do
        @platform = 'eos-4-x86_64'
        expect {
          instance.package_config_dir
        }.to raise_error( ArgumentError, /package\ config\ dir\ unknown/ )
      end
    end

    describe '#repo_filename' do

      it 'sets the el portion correctly for centos platforms' do
        @platform = 'centos-5-x86_64'
        allow( instance ).to receive( :is_pe? ) { false }
        filename = instance.repo_filename( 'pkg_name', 'pkg_version7' )
        expect( filename ).to match( /sion7\-el\-/ )
      end

      it 'builds the filename correctly for el-based platforms' do
        @platform = 'el-21-x86_64'
        allow( instance ).to receive( :is_pe? ) { false }
        filename = instance.repo_filename( 'pkg_name', 'pkg_version8' )
        correct = 'pl-pkg_name-pkg_version8-el-21-x86_64.repo'
        expect( filename ).to be === correct
      end

      it 'adds in the PE portion of the filename correctly for el-based PE hosts' do
        @platform = 'el-21-x86_64'
        allow( instance ).to receive( :is_pe? ) { true }
        filename = instance.repo_filename( 'pkg_name', 'pkg_version9' )
        correct = 'pl-pkg_name-pkg_version9-repos-pe-el-21-x86_64.repo'
        expect( filename ).to be === correct
      end

      it 'builds the filename correctly for debian-based platforms' do
        @platform = 'debian-8-x86_64'
        filename = instance.repo_filename( 'pkg_name', 'pkg_version10' )
        correct = 'pl-pkg_name-pkg_version10-jessie.list'
        expect( filename ).to be === correct
      end

      it 'uses the variant for the codename on the cumulus platform' do
        @platform = 'cumulus-2.5-x86_64'
        filename = instance.repo_filename( 'pkg_name', 'pkg_version11' )
        correct = 'pl-pkg_name-pkg_version11-cumulus.list'
        expect( filename ).to be === correct
      end

      it 'adds wrlinux to variant on cisco platforms' do
        @platform = 'cisco_nexus-7-x86_64'
        allow( instance ).to receive( :is_pe? ) { false }
        filename = instance.repo_filename( 'pkg_name', 'pkg_version12' )
        expect( filename ).to match( /sion12\-cisco\-wrlinux\-/ )
      end

      it 'errors for non-el or debian-based platforms' do
        @platform = 'freebsd-22-x86_64'
        expect {
          instance.repo_filename( 'pkg_name', 'pkg_version' )
        }. to raise_error( ArgumentError, /repo\ filename\ pattern\ not\ known/ )
      end
    end

    describe '#noask_file_text' do

      it 'errors on non-solaris platforms' do
        @platform = 'cumulus-4000-x86_64'
        expect {
          instance.noask_file_text
        }.to raise_error( ArgumentError, /^noask\ file\ text\ unknown/ )
      end

      it 'errors on solaris versions other than 10' do
        @platform = 'solaris-11-x86_64'
        expect {
          instance.noask_file_text
        }.to raise_error( ArgumentError, /^noask\ file\ text\ unknown/ )
      end

      it 'returns the noask file correctly for solaris 10' do
        @platform = 'solaris-10-x86_64'
        text = instance.noask_file_text
        expect( text ).to match( /instance\=overwrite/ )
        expect( text ).to match( /space\=quit/ )
        expect( text ).to match( /basedir\=default/ )
      end
    end
  end
end
