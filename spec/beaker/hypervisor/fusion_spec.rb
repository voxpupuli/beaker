require 'spec_helper'

module Beaker
  describe Fusion do
    let( :fusion ) { Beaker::Fusion.new( @hosts, make_opts ) }

    before :each do
      stub_const( "Fission::VM", true )
      @hosts = make_hosts()
      MockFission.presets( @hosts )
      Fusion.any_instance.stub( :require ).with( 'fission' ).and_return( true )
      fusion.instance_variable_set( :@fission, MockFission ) 
    end

    it "can provision a set of hosts" do
      fusion.provision
    end

    it "raises an error if unknown snapshot name is used" do
      @hosts[0][:snapshot] = 'unknown'
      expect{ fusion.provision }.to raise_error
    end

  end

end
