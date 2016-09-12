require 'spec_helper'
require 'fog'

module Beaker
  describe OpenStack do

    let(:options) { make_opts.merge({'logger' => double().as_null_object}) }

    let(:openstack) {
      OpenStack.new(@hosts, options)
    }

    before :each do
      @hosts = make_hosts()

      @compute_client = double().as_null_object
      @network_client = double().as_null_object

      allow( Fog::Compute ).to receive( :new ).and_return( @compute_client )
      allow( Fog::Network ).to receive( :new ).and_return( @network_client )
    end

    it 'check openstack options during initialization' do
      options = openstack.instance_eval('@options')
      expect(options['openstack_api_key']).to eq('P1as$w0rd')
      expect(options['openstack_username']).to eq('user')
      expect(options['openstack_auth_url']).to eq('http://openstack_hypervisor.labs.net:5000/v2.0/tokens')
      expect(options['openstack_tenant']).to eq('testing')
      expect(options['openstack_network']).to eq('testing')
      expect(options['openstack_keyname']).to eq('nopass')
      expect(options['security_group']).to eq(['my_sg', 'default'])
      expect(options['floating_ip_pool']).to eq('my_pool')
    end

    it 'check hosts options during initialization' do
      hosts = openstack.instance_eval('@hosts')
      @hosts.each do |host|
        expect(host['image']).to eq('default_image')
        expect(host['flavor']).to eq('m1.large')
        expect(host['user_data']).to eq('#cloud-config\nmanage_etc_hosts: true\nfinal_message: "The host is finally up!"')
      end
    end

    it 'check host options during server creation' do

      mock_flavor = Object.new
      allow( mock_flavor ).to receive( :id ).and_return( 12345 )
      allow( openstack ).to receive( :flavor ).and_return( mock_flavor )
      expect( openstack ).to receive( :flavor ).with( 'm1.large' )

      mock_image = Object.new
      allow( mock_image ).to receive( :id ).and_return( 54321 )
      allow( openstack ).to receive( :image ).and_return( mock_image )
      expect( openstack ).to receive( :image ).with( 'default_image' )

      mock_servers = double().as_null_object
      allow( @compute_client ).to receive( :servers ).and_return( mock_servers )

      expect(mock_servers).to receive(:create).with(hash_including(
        :user_data => '#cloud-config\nmanage_etc_hosts: true\nfinal_message: "The host is finally up!"',
        :flavor_ref => 12345,
        :image_ref => 54321)
      )

      openstack.provision
    end

  end
end
