require 'spec_helper'

module Beaker
  describe Aixer do
    let( :aixer) { Beaker::Aixer.new( @hosts, make_opts ) }

    before :each do
      @hosts = make_hosts()
      allow( File ).to receive( :exists? ).and_return( true )
      allow( YAML ).to receive( :load_file ).and_return( fog_file_contents )
      allow_any_instance_of( Host ).to receive( :exec ).and_return( true )
    end

    it "can provision a set of hosts" do
      @hosts.each do |host|
        expect( Command ).to receive( :new ).with( "cd pe-aix && rake restore:#{host.name}" ).once

      end

      aixer.provision

    end

    it "does nothing for cleanup" do
      expect( Command ).to receive( :new ).never
      expect( Host ).to receive( :exec ).never

      aixer.cleanup

    end


  end
end
