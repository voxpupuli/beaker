require 'spec_helper'

module Beaker
  describe Unix::Pkg do
    class UnixPkgTest
      include Unix::Pkg

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
    let (:instance) { UnixPkgTest.new(opts, logger) }

    context "check_for_package" do

      it "checks correctly on sles" do
        @opts = {'platform' => 'sles-is-me'}
        pkg = 'sles_package'
        expect( Beaker::Command ).to receive(:new).with("zypper se -i --match-exact #{pkg}").and_return('')
        expect( instance ).to receive(:exec).with('', :acceptable_exit_codes => (0...127)).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.check_for_package(pkg) ).to be === true
      end
 
      it "checks correctly on fedora" do
        @opts = {'platform' => 'fedora-is-me'}
        pkg = 'fedora_package'
        expect( Beaker::Command ).to receive(:new).with("rpm -q #{pkg}").and_return('')
        expect( instance ).to receive(:exec).with('', :acceptable_exit_codes => (0...127)).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.check_for_package(pkg) ).to be === true
      end

      it "checks correctly on centos" do
        @opts = {'platform' => 'centos-is-me'}
        pkg = 'centos_package'
        expect( Beaker::Command ).to receive(:new).with("rpm -q #{pkg}").and_return('')
        expect( instance ).to receive(:exec).with('', :acceptable_exit_codes => (0...127)).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.check_for_package(pkg) ).to be === true
      end

      it "checks correctly on EOS" do
        @opts = {'platform' => 'eos-is-me'}
        pkg = 'eos-package'
        expect( Beaker::Command ).to receive(:new).with("rpm -q #{pkg}").and_return('')
        expect( instance ).to receive(:exec).with('', :acceptable_exit_codes => (0...127)).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.check_for_package(pkg) ).to be === true
      end

      it "checks correctly on el-" do
        @opts = {'platform' => 'el-is-me'}
        pkg = 'el_package'
        expect( Beaker::Command ).to receive(:new).with("rpm -q #{pkg}").and_return('')
        expect( instance ).to receive(:exec).with('', :acceptable_exit_codes => (0...127)).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.check_for_package(pkg) ).to be === true
      end

      it "checks correctly on debian" do
        @opts = {'platform' => 'debian-is-me'}
        pkg = 'debian_package'
        expect( Beaker::Command ).to receive(:new).with("dpkg -s #{pkg}").and_return('')
        expect( instance ).to receive(:exec).with('', :acceptable_exit_codes => (0...127)).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.check_for_package(pkg) ).to be === true
      end

      it "checks correctly on ubuntu" do
        @opts = {'platform' => 'ubuntu-is-me'}
        pkg = 'ubuntu_package'
        expect( Beaker::Command ).to receive(:new).with("dpkg -s #{pkg}").and_return('')
        expect( instance ).to receive(:exec).with('', :acceptable_exit_codes => (0...127)).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.check_for_package(pkg) ).to be === true
      end

      it "checks correctly on cumulus" do
        @opts = {'platform' => 'cumulus-is-me'}
        pkg = 'cumulus_package'
        expect( Beaker::Command ).to receive(:new).with("dpkg -s #{pkg}").and_return('')
        expect( instance ).to receive(:exec).with('', :acceptable_exit_codes => (0...127)).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.check_for_package(pkg) ).to be === true
      end

      it "checks correctly on solaris-11" do
        @opts = {'platform' => 'solaris-11-is-me'}
        pkg = 'solaris-11_package'
        expect( Beaker::Command ).to receive(:new).with("pkg info #{pkg}").and_return('')
        expect( instance ).to receive(:exec).with('', :acceptable_exit_codes => (0...127)).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.check_for_package(pkg) ).to be === true
      end

      it "checks correctly on solaris-10" do
        @opts = {'platform' => 'solaris-10-is-me'}
        pkg = 'solaris-10_package'
        expect( Beaker::Command ).to receive(:new).with("pkginfo #{pkg}").and_return('')
        expect( instance ).to receive(:exec).with('', :acceptable_exit_codes => (0...127)).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.check_for_package(pkg) ).to be === true
      end

      it "returns false for el-4" do
        @opts = {'platform' => 'el-4-is-me'}
        pkg = 'el-4_package'
        expect( instance.check_for_package(pkg) ).to be === false
      end

      it "raises on unknown platform" do
        @opts = {'platform' => 'nope-is-me'}
        pkg = 'nope_package'
        expect{ instance.check_for_package(pkg) }.to raise_error

      end
       
     end
 
   end
 end
 
