require 'spec_helper'

module Beaker
  describe Fog do
    let( :options ) { make_opts.merge({ 'logger' => double().as_null_object }) }
    let( :fog ) { Beaker::Fog.new( @hosts, options ) }

    before :each do
      @hosts = make_hosts( {
                              :cloud_provider => 'DigitalOcean',
                              :digitalocean_api_key => 'Foo',
                              :digitalocean_client_id => 'Bar',
                            }
                          )
    end

    it "can provision a set of hosts" do
      ::Fog.mock!
      allow(File).to receive(:read).with(File.expand_path('~/.ssh/id_rsa')).and_return('Key')
      allow(File).to receive(:read).with(File.expand_path('~/.ssh/id_rsa.pub')).and_return('Pub Key')
      fog.provision
    end

  end
end
