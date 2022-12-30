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

    let(:opts)     { @opts || {} }
    let(:logger)   { double( 'logger' ).as_null_object }
    let(:instance) { FreeBSDPkgTest.new(opts, logger) }
    let(:cond) do
      'TMPDIR=/dev/null ASSUME_ALWAYS_YES=1 PACKAGESITE=file:///nonexist pkg info -x "pkg(-devel)?\\$" > /dev/null 2>&1'
    end

    context "pkg_info_patten" do
      it "returns correct patterns" do
        expect( instance.pkg_info_pattern('rsync') ).to eq '^rsync-[0-9][0-9a-zA-Z_\\.,]*$'
      end
    end

    context "check_pkgng_sh" do
      it { expect( instance.check_pkgng_sh ).to eq cond }
    end

    context "pkgng_active?" do
      it "returns true if pkgng is available" do
        expect( instance ).to receive(:check_pkgng_sh).once.and_return("do you have pkgng?")
        expect( Beaker::Command ).to receive(:new).with("/bin/sh -c 'do you have pkgng?'", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
        expect( instance ).to receive(:exec).with('',{:accept_all_exit_codes => true}).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.pkgng_active? ).to be true
      end

      it "returns false if pkgng is unavailable" do
        expect( instance ).to receive(:check_pkgng_sh).once.and_return("do you have pkgng?")
        expect( Beaker::Command ).to receive(:new).with("/bin/sh -c 'do you have pkgng?'", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
        expect( instance ).to receive(:exec).with('',{:accept_all_exit_codes => true}).and_return(generate_result("hello", {:exit_code => 127}))
        expect( instance.pkgng_active? ).to be false
      end
    end

    context "install_package" do
      context "without pkgng" do
        it "runs the correct install command" do
          expect( instance ).to receive(:pkgng_active?).once.and_return(false)
          expect( Beaker::Command ).to receive(:new).with("pkg_add -r rsync", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
          expect( instance ).to receive(:exec).with('', {}).and_return(generate_result("hello", {:exit_code => 0}))
          instance.install_package('rsync')
        end
      end

      context "with pkgng" do
        it "runs the correct install command" do
          expect( instance ).to receive(:pkgng_active?).once.and_return(true)
          expect( Beaker::Command ).to receive(:new).with("pkg install -y rsync", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
          expect( instance ).to receive(:exec).with('', {}).and_return(generate_result("hello", {:exit_code => 0}))
          instance.install_package('rsync')
        end
      end
    end

    context "check_for_package" do
      context "without pkgng" do
        it "runs the correct checking command" do
          expect( instance ).to receive(:pkgng_active?).once.and_return(false)
          expect( Beaker::Command ).to receive(:new).with("pkg_info -Ix '^rsync-[0-9][0-9a-zA-Z_\\.,]*$'", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
          expect( instance ).to receive(:exec).with('', {:accept_all_exit_codes => true}).and_return(generate_result("hello", {:exit_code => 0}))
          instance.check_for_package('rsync')
        end
      end

      context "with pkgng" do
        it "runs the correct checking command" do
          expect( instance ).to receive(:pkgng_active?).once.and_return(true)
          expect( Beaker::Command ).to receive(:new).with("pkg info rsync", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
          expect( instance ).to receive(:exec).with('', {:accept_all_exit_codes => true}).and_return(generate_result("hello", {:exit_code => 0}))
          instance.check_for_package('rsync')
        end
      end
    end

  end
end

