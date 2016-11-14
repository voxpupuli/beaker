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

      @hosts.each do |host|
        allow(host).to receive(:wait_for_port).and_return(true)
      end

      openstack.provision
    end

    it 'generates valid keynames during server creation' do
      # Simulate getting a dynamic IP from OpenStack to test key generation code
      # after provisioning. See _validate_new_key_pair in openstack/nova for reference
      mock_ip = double().as_null_object
      allow( openstack ).to receive( :get_ip ).and_return( mock_ip )
      allow( mock_ip ).to receive( :ip ).and_return( '172.16.0.1' )
      openstack.instance_eval('@options')['openstack_keyname'] = nil

      @hosts.each do |host|
        allow(host).to receive(:wait_for_port).and_return(true)
      end

      openstack.provision

      @hosts.each do |host|
        expect(host[:keyname]).to match(/[_\-0-9a-zA-Z]+/)
      end
    end

    it 'get_ip always allocates a new floatingip' do
      # Assume beaker is being executed in parallel N times by travis (or similar).
      # IPs are allocated (but not associated) before an instance is created; it is
      # hightly possible the first instance will allocate a new IP and create an ssh
      # key.  While the instance is being created the other N-1 instances come along,
      # find the unused IP and try to use it as well which causes keyname clashes
      # and other IP related shenannigans.  Ensure we allocate a new IP each and every
      # time
      mock_addresses = double().as_null_object
      mock_ip = double().as_null_object
      allow(@compute_client).to receive(:addresses).and_return(mock_addresses)
      allow(mock_addresses).to receive(:create).and_return(mock_ip)
      expect(mock_addresses).to receive(:create).exactly(3).times
      (1..3).each { openstack.get_ip }
    end

    it 'creates volumes with cinder v1' do
      # Mock a volume
      allow(openstack).to receive(:get_volumes).and_return({'volume1' => {'size' => 1000000 }})

      # Stub out the call to create the client and hard code the return value
      allow(openstack).to receive(:volume_client_create).and_return(nil)
      client = double().as_null_object
      openstack.instance_variable_set(:@volume_client, client)
      allow(openstack).to receive(:get_volume_api_version).and_return(1)

      # Check the parameters are valid, correct 'name' parameter and correct size conversion
      mock_volume = double().as_null_object
      expect(client).to receive(:create).with(:display_name => 'volume1', :description => 'Beaker volume: host=alan volume=volume1', :size => 1000).and_return(mock_volume)
      allow(mock_volume).to receive(:wait_for).and_return(nil)

      # Perform the test!
      mock_vm = double().as_null_object
      allow(mock_volume).to receive(:id).and_return('Fake ID')
      expect(mock_vm).to receive(:attach_volume).with('Fake ID', '/dev/vdb')

      mock_host = double().as_null_object
      allow(mock_host).to receive(:name).and_return('alan')

      openstack.provision_storage mock_host, mock_vm
    end

    it 'creates volumes with cinder v2' do
      # Mock a volume
      allow(openstack).to receive(:get_volumes).and_return({'volume1' => {'size' => 1000000 }})

      # Stub out the call to create the client and hard code the return value
      allow(openstack).to receive(:volume_client_create).and_return(nil)
      client = double().as_null_object
      openstack.instance_variable_set(:@volume_client, client)
      allow(openstack).to receive(:get_volume_api_version).and_return(-1)

      # Check the parameters are valid, correct 'name' parameter and correct size conversion
      mock_volume = double().as_null_object
      expect(client).to receive(:create).with(:name => 'volume1', :description => 'Beaker volume: host=alan volume=volume1', :size => 1000).and_return(mock_volume)
      allow(mock_volume).to receive(:wait_for).and_return(nil)

      # Perform the test!
      mock_vm = double().as_null_object
      allow(mock_volume).to receive(:id).and_return('Fake ID')
      expect(mock_vm).to receive(:attach_volume).with('Fake ID', '/dev/vdb')

      mock_host = double().as_null_object
      allow(mock_host).to receive(:name).and_return('alan')

      openstack.provision_storage mock_host, mock_vm
    end

  end
end
