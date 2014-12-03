require 'spec_helper'

module Beaker
  describe Fusion do
    let( :fusion ) { Beaker::Fusion.new( @hosts, make_opts ) }

    before :each do
     stub_const( "Fission::VM", true )
      @hosts = make_hosts()
      MockFission.presets( @hosts )
      allow_any_instance_of( Fusion ).to receive( :require ).with( 'fission' ).and_return( true )
      fusion.instance_variable_set( :@fission, MockFission ) 
    end

    it "can interoperate with the fission library to provision hosts"  do
      fusion.provision
    end

    it "raises an error if unknown snapshot name is used" do
      @hosts[0][:snapshot] = 'unknown'
      expect{ fusion.provision }.to raise_error
    end

    it 'raises an error if snapshots is nil' do
      MockFissionVM.set_snapshots(nil)
      expect{ fusion.provision }.to raise_error(/No snapshots available/)
    end

    it 'raises an error if snapshots are empty' do
      MockFissionVM.set_snapshots([])
      expect{ fusion.provision }.to raise_error(/No snapshots available/)
    end

    it 'host fails init with nil snapshot' do
      @hosts[0][:snapshot] = nil
      expect{ Beaker::Fusion.new( @hosts, make_opts) }.to raise_error(/specify a snapshot/)
    end

  end

end
