require 'spec_helper'

module Beaker
  describe Fusion do
    let( :logger ) { double( 'logger' ).as_null_object }
    let( :defaults ) { Beaker::Options::OptionsHash.new.merge( { :logger => logger} ) }
    let( :options ) { @options ? defaults.merge( @options ) : defaults}

    let( :fusion ) { Beaker::Fusion.new( @hosts, options ) }
    let( :vms ) { ['vm1', 'vm2', 'vm3'] }
    let( :snaps )  { ['snapshot1', 'snapshot2', 'snapshot3'] }

    def make_host name, snap
      opts = Beaker::Options::OptionsHash.new.merge( { :logger => logger, 'HOSTS' => { name => { 'platform' => 'unix', :snapshot => snap } } } )
      Host.create( name, opts )
    end

    def make_hosts names, snaps
      hosts = []
      names.zip(snaps).each do |vm, snap|
        hosts << make_host( vm, snap )
      end
      hosts
    end

    before :each do
      MockFission.presets(vms, snaps)
    end

    it "can provision a set of hosts" do
      @hosts = make_hosts( vms, snaps )
      fusion.instance_variable_set( :@fission, MockFission ) 
      fusion.provision
    end

    it "raises an error if unknown snapshot name is used" do
      @hosts = []
      @hosts << make_host( 'vm1', 'unkown' )
      fusion.instance_variable_set( :@fission, MockFission ) 
      expect{ fusion.provision }.to raise_error
    end

  end

end
