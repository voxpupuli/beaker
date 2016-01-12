require 'spec_helper'

module Unix
  describe Host do
    let( :options )  { @options ? @options : {} }
    let( :platform ) {
      if @platform
        { :platform => Beaker::Platform.new( @platform) }
      else
        { :platform => Beaker::Platform.new( 'el-vers-arch-extra' ) }
      end
    }
    let( :host )    { make_host( 'name', options.merge(platform) ) }
    let( :opts )    { { :download_url => 'download_url' } }


    describe '#solaris_puppet_agent_dev_package_info' do
      it 'raises an error if puppet_collection is not passed' do
        expect {
          host.solaris_puppet_agent_dev_package_info
        }.to raise_error( ArgumentError, /^Must\ provide\ puppet_collection/ )
      end

      it 'raises an error if puppet_agent_version is not passed' do
        expect {
          host.solaris_puppet_agent_dev_package_info( 'collection' )
        }.to raise_error( ArgumentError, /^Must\ provide\ puppet_agent_version/ )
      end

      it 'raises an error if the download URL is not passed' do
        expect {
          host.solaris_puppet_agent_dev_package_info( 'collection', 'version' )
        }.to raise_error( ArgumentError, /^Must\ provide\ opts\[\:download_url\]/ )
      end

      it 'raises an error if called on a non-solaris platform' do
        @platform = 'ubuntu-14.04-x86_64'
        opts = { :download_url => 'download_url' }
        expect {
          host.solaris_puppet_agent_dev_package_info( 'collection', 'version', opts )
        }.to raise_error( ArgumentError, /^Incorrect\ platform \'ubuntu\'/ )
      end

      it 'sets release_path_end correctly' do
        @platform = 'solaris-10-arch'
        allow( host ).to receive( :link_exists? ) { true }
        release_path_end, _ = host.solaris_puppet_agent_dev_package_info(
          'pa_collection4', 'pa_version', opts )
        expect( release_path_end ).to be === "solaris/10/pa_collection4"
      end

      it 'sets the arch correctly for x86_64 platforms' do
        @platform = 'solaris-10-x86_64'
        allow( host ).to receive( :link_exists? ) { true }
        _, release_file = host.solaris_puppet_agent_dev_package_info(
          'pa_collection', 'pa_version', opts )
        expect( release_file ).to     match( /i386/   )
        expect( release_file ).not_to match( /x86_64/ )
      end

      context 'sets release_file name appropriately for puppet-agent version' do
        context 'on solaris 10' do
          before :each do
            @platform = 'solaris-10-arch'
          end

          [ '1.0.1.786.477',
            '1.0.1.786.a477',
            '1.0.1.786.477-',
            '1.0.1.0000786.477',
            '1.000000.1.786.477',
            '-1.0.1.786.477',
            '1.2.5.38.6813',
          ].each do |pa_version|

            context "#{pa_version}" do
              it "URL exists" do
                allow( host ).to receive( :link_exists? ) { true }
                _, release_file = host.solaris_puppet_agent_dev_package_info(
                  'pa_collection', pa_version, opts )
                expect( release_file ).to be === "puppet-agent-#{pa_version}-1.arch.pkg.gz"
              end

              it "fallback URL" do
                allow( host ).to receive( :link_exists? ) { false }
                _, release_file = host.solaris_puppet_agent_dev_package_info(
                  'pa_collection', pa_version, opts )
                expect( release_file ).to be === "puppet-agent-#{pa_version}.arch.pkg.gz"
              end
            end
          end
        end

        context 'on solaris 11' do
          before :each do
            @platform = 'solaris-11-arch'
          end

          [
            ['1.0.1.786.477', '1.0.1.786.477'],
            ['1.0.1.786.a477', '1.0.1.786.477'],
            ['1.0.1.786.477-', '1.0.1.786.477'],
            ['1.0.1.0000786.477', '1.0.1.786.477'],
            ['1.000000.1.786.477', '1.0.1.786.477'],
            ['-1.0.1.786.477', '1.0.1.786.477'],
            ['1.2.5-78-gbb3022f', '1.2.5.78.3022'],
            ['1.2.5.38.6813', '1.2.5.38.6813']
          ].each do |pa_version, pa_version_cleaned|

            context "#{pa_version}" do
              it "URL exists" do
                allow( host ).to receive( :link_exists? ) { true }
                _, release_file = host.solaris_puppet_agent_dev_package_info(
                  'pa_collection', pa_version, opts )
                expect( release_file ).to be === "puppet-agent@#{pa_version_cleaned},5.11-1.arch.p5p"
              end

              it "fallback URL" do
                allow( host ).to receive( :link_exists? ) { false }
                _, release_file = host.solaris_puppet_agent_dev_package_info(
                  'pa_collection', pa_version, opts )
                expect( release_file ).to be === "puppet-agent@#{pa_version_cleaned},5.11.arch.p5p"
              end
            end
          end
        end
      end
    end

    describe '#puppet_agent_dev_package_info' do

      it 'raises an error if puppet_collection is not passed' do
        expect {
          host.puppet_agent_dev_package_info
        }.to raise_error( ArgumentError, /^Must\ provide\ puppet_collection/ )
      end

      it 'raises an error if puppet_agent_version is not passed' do
        expect {
          host.puppet_agent_dev_package_info( 'collection' )
        }.to raise_error( ArgumentError, /^Must\ provide\ puppet_agent_version/ )
      end

      it 'raises an error on unknown platforms' do
        @platform = 'ubuntu-14.04-x86_64'
        expect {
          host.puppet_agent_dev_package_info( 'collection', 'version' )
        }.to raise_error( ArgumentError, /^puppet_agent\ dev\ package\ info\ unknown/ )
      end

      it 'calls out to the right method for solaris & returns what it gets' do
        @platform = 'solaris-10-x86_64'
        release_path_end_correct = 'release_path_end_correct_1'
        release_file_correct = 'release_file_correct_1'
        allow( host ).to receive( :solaris_puppet_agent_dev_package_info ) {
          [release_path_end_correct, release_file_correct]
        }

        release_path_end, release_file = host.puppet_agent_dev_package_info(
          'pa_collection', 'pa_version' )
        expect( release_path_end ).to be === release_path_end_correct
        expect( release_file ).to be === release_file_correct
      end

      it 'sets up sles|aix platforms correctly' do
        @platform = 'sles-12-arch'
        release_path_end, release_file = host.puppet_agent_dev_package_info(
          'pa_collection', 'pa_version1' )
        expect( release_path_end ).to be === "sles/12/pa_collection/arch"
        expect( release_file ).to be === "puppet-agent-pa_version1-1.sles12.arch.rpm"
      end

      it 'sets the arch correctly on aix-power platforms' do
        @platform = 'aix-14-power'
        release_path_end, release_file = host.puppet_agent_dev_package_info(
          'pa_collection', 'pa_version2' )
        expect( release_path_end ).to be === "aix/14/pa_collection/ppc"
        expect( release_file ).to be === "puppet-agent-pa_version2-1.aix14.ppc.rpm"
      end
    end

    describe '#external_copy_base' do

      it 'returns /root in general' do
        copy_base = host.external_copy_base
        expect( copy_base ).to be === '/root'
      end

      it 'returns /root if solaris but not version 10' do
        @platform = 'solaris-11-arch'
        copy_base = host.external_copy_base
        expect( copy_base ).to be === '/root'
      end

      it 'returns / if on a solaris 10 platform' do
        @platform = 'solaris-10-arch'
        copy_base = host.external_copy_base
        expect( copy_base ).to be === '/'
      end
    end

    describe '#determine_ssh_server' do
      it 'returns :openssh' do
        expect( host.determine_ssh_server ).to be === :openssh
      end
    end
  end
end