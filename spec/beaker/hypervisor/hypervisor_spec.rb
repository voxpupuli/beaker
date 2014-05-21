require 'spec_helper'

module Beaker
  describe Hypervisor do
    let( :hypervisor ) { Beaker::Hypervisor }

    it "creates an aix hypervisor for aix hosts" do
      aix = double( 'aix' )
      aix.stub( :provision ).and_return( true )

      Aixer.should_receive( :new ).once.and_return( aix )
      expect( hypervisor.create( 'aix', [], make_opts() ) ).to be === aix
    end

    it "creates a solaris hypervisor for solaris hosts" do
      solaris = double( 'solaris' )
      solaris.stub( :provision ).and_return( true )
      Solaris.should_receive( :new ).once.and_return( solaris )
      expect( hypervisor.create( 'solaris', [], make_opts() ) ).to be === solaris
    end

    it "creates a vsphere hypervisor for vsphere hosts" do
      vsphere = double( 'vsphere' )
      vsphere.stub( :provision ).and_return( true )
      Vsphere.should_receive( :new ).once.and_return( vsphere )
      expect( hypervisor.create( 'vsphere', [], make_opts() ) ).to be === vsphere
    end

    it "creates a fusion hypervisor for fusion hosts" do
      fusion = double( 'fusion' )
      fusion.stub( :provision ).and_return( true )
      Fusion.should_receive( :new ).once.and_return( fusion )
      expect( hypervisor.create( 'fusion', [], make_opts() ) ).to be === fusion
    end

    it "creates a vcloudpooled hypervisor for vcloud hosts that are pooled" do
      vcloud = double( 'vcloud' )
      vcloud.stub( :provision ).and_return( true )
      VcloudPooled.should_receive( :new ).once.and_return( vcloud )
      expect( hypervisor.create( 'vcloud', [], make_opts().merge( { 'pooling_api' => true } ) ) ).to be === vcloud
    end

    it "creates a vcloud hypervisor for vcloud hosts that are not pooled" do
      vcloud = double( 'vcloud' )
      vcloud.stub( :provision ).and_return( true )
      Vcloud.should_receive( :new ).once.and_return( vcloud )
      expect( hypervisor.create( 'vcloud', [], make_opts().merge( { 'pooling_api' => false } ) ) ).to be === vcloud
    end

    it "creates a vagrant hypervisor for vagrant hosts" do
      vagrant = double( 'vagrant' )
      vagrant.stub( :provision ).and_return( true )
      Vagrant.should_receive( :new ).once.and_return( vagrant )
      expect( hypervisor.create( 'vagrant', [], make_opts() ) ).to be === vagrant
    end

    it "creates a vagrant_fusion hypervisor for vagrant vmware fusion hosts" do
      vagrant = double( 'vagrant_fusion' )
      vagrant.stub( :provision ).and_return( true )
      VagrantFusion.should_receive( :new ).once.and_return( vagrant )
      expect( hypervisor.create( 'vagrant_fusion', [], make_opts() ) ).to be === vagrant
    end

    it "creates a vagrant_virtualbox hypervisor for vagrant virtualbox hosts" do
      vagrant = double( 'vagrant_virtualbox' )
      vagrant.stub( :provision ).and_return( true )
      VagrantVirtualbox.should_receive( :new ).once.and_return( vagrant )
      expect( hypervisor.create( 'vagrant_virtualbox', [], make_opts() ) ).to be === vagrant
    end

    it "creates a blimpy hypervisor for blimpy hosts" do
      blimpy = double( 'blimpy' )
      blimpy.stub( :provision ).and_return( true )
      Blimper.should_receive( :new ).once.and_return( blimpy )
      expect( hypervisor.create( 'blimpy', [], make_opts() ) ).to be === blimpy
    end


  end
end
