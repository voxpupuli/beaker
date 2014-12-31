require 'spec_helper'

module Beaker
  describe Hypervisor do
    let( :hypervisor ) { Beaker::Hypervisor }

    it "creates an aix hypervisor for aix hosts" do
      aix = double( 'aix' )
      allow( aix ).to receive( :provision ).and_return( true )

      expect( Aixer ).to receive( :new ).once.and_return( aix )
      expect( hypervisor.create( 'aix', [], make_opts() ) ).to be === aix
    end

    it "creates a solaris hypervisor for solaris hosts" do
      solaris = double( 'solaris' )
      allow( solaris ).to receive( :provision ).and_return( true )
      expect( Solaris ).to receive( :new ).once.and_return( solaris )
      expect( hypervisor.create( 'solaris', [], make_opts() ) ).to be === solaris
    end

    it "creates a vsphere hypervisor for vsphere hosts" do
      vsphere = double( 'vsphere' )
      allow( vsphere ).to receive( :provision ).and_return( true )
      expect( Vsphere ).to receive( :new ).once.and_return( vsphere )
      expect( hypervisor.create( 'vsphere', [], make_opts() ) ).to be === vsphere
    end

    it "creates a fusion hypervisor for fusion hosts" do
      fusion = double( 'fusion' )
      allow( fusion ).to receive( :provision ).and_return( true )
      expect( Fusion ).to receive( :new ).once.and_return( fusion )
      expect( hypervisor.create( 'fusion', [], make_opts() ) ).to be === fusion
    end

    it "creates a vcloudpooled hypervisor for vcloud hosts that are pooled" do
      vcloud = double( 'vcloud' )
      allow( vcloud ).to receive( :provision ).and_return( true )
      expect( VcloudPooled ).to receive( :new ).once.and_return( vcloud )
      expect( hypervisor.create( 'vcloud', [], make_opts().merge( { 'pooling_api' => true } ) ) ).to be === vcloud
    end

    it "creates a vcloud hypervisor for vcloud hosts that are not pooled" do
      vcloud = double( 'vcloud' )
      allow( vcloud ).to receive( :provision ).and_return( true )
      expect( Vcloud ).to receive( :new ).once.and_return( vcloud )
      expect( hypervisor.create( 'vcloud', [], make_opts().merge( { 'pooling_api' => false } ) ) ).to be === vcloud
    end

    it "creates a vagrant hypervisor for vagrant hosts" do
      vagrant = double( 'vagrant' )
      allow( vagrant ).to receive( :provision ).and_return( true )
      expect( Vagrant ).to receive( :new ).once.and_return( vagrant )
      expect( hypervisor.create( 'vagrant', [], make_opts() ) ).to be === vagrant
    end

    it "creates a vagrant_fusion hypervisor for vagrant vmware fusion hosts" do
      vagrant = double( 'vagrant_fusion' )
      allow( vagrant ).to receive( :provision ).and_return( true )
      expect( VagrantFusion ).to receive( :new ).once.and_return( vagrant )
      expect( hypervisor.create( 'vagrant_fusion', [], make_opts() ) ).to be === vagrant
    end

    it "creates a vagrant_virtualbox hypervisor for vagrant virtualbox hosts" do
      vagrant = double( 'vagrant_virtualbox' )
      allow( vagrant ).to receive( :provision ).and_return( true )
      expect( VagrantVirtualbox ).to receive( :new ).once.and_return( vagrant )
      expect( hypervisor.create( 'vagrant_virtualbox', [], make_opts() ) ).to be === vagrant
    end

    context "#configure" do
      let( :options ) { make_opts.merge({ 'logger' => double().as_null_object }) }
      let( :hosts ) { make_hosts( { :platform => 'el-5' } ) }
      let( :hypervisor ) { Beaker::Hypervisor.new( hosts, options ) }

      context "if :disable_iptables option set false" do
        it "does not call disable_iptables" do
          options[:disable_iptables] = false
          expect( hypervisor ).to receive( :disable_iptables ).never
          hypervisor.configure
        end
      end

      context "if :disable_iptables option set true" do
        it "calls disable_iptables once" do
          options[:disable_iptables] = true
          expect( hypervisor ).to receive( :disable_iptables ).exactly( 1 ).times
          hypervisor.configure
        end
      end

      context 'if :configure option set false' do
        it 'does not make any configure calls' do
          options[:configure]         = false
          options[:timesync]          = true
          options[:root_keys]         = true
          options[:add_el_extras]     = true
          options[:disable_iptables]  = true
          expect( hypervisor ).to_not receive( :timesync )
          expect( hypervisor ).to_not receive( :sync_root_keys )
          expect( hypervisor ).to_not receive( :add_el_extras )
          expect( hypervisor ).to_not receive( :disable_iptables )
          expect( hypervisor ).to_not receive( :set_env )
          hypervisor.configure
        end
      end

      context 'if :configure option set true' do
        it 'does call set_env' do
          options[:configure] = true
          expect( hypervisor ).to receive( :set_env ).once
          hypervisor.configure
        end
      end

    end

  end
end
