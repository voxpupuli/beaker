require 'spec_helper'
require 'fog'

module Beaker
  describe OpenStack do

    let(:options) { make_opts.merge({'logger' => double().as_null_object}) }

    let(:openstack) {
      stub_const("Fog::Compute", MockComputeClient)
      stub_const("Fog::Network", MockNetworkClient)
      Beaker::OpenStack.new(@hosts, options)
    }

    before :each do
      @hosts = make_hosts()
    end

    it 'check openstack options during initialization' do
      options = openstack.instance_eval('@options')
      expect(options['openstack_api_key']).to eq('P1as$w0rd')
      expect(options['openstack_username']).to eq('user')
      expect(options['openstack_auth_url']).to eq('http://openstack_hypervisor.labs.net:5000/v2.0/tokens')
      expect(options['openstack_tenant']).to eq('testing')
      expect(options['openstack_network']).to eq('testing')
      expect(options['openstack_keyname']).to eq('nopass')
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
      openstack.provision
      compute_options = openstack.instance_eval('@compute_client').create_options

      expect(compute_options[:flavor_ref]).to eq('testid')
      expect(compute_options[:image_ref]).to eq('testid')
      expect(compute_options[:user_data]).to eq('#cloud-config\nmanage_etc_hosts: true\nfinal_message: "The host is finally up!"')
    end

  end
end
