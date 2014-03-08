require 'spec_helper'

module Beaker
  describe GoogleCompute do
    let( :gc ) { Beaker::GoogleCompute.new( @hosts, make_opts ) }

    before :each do
      @hosts = make_hosts()
      apiclient = double()

    end

    it "can provision hosts" do
      gc.provision

    end




  end

end
