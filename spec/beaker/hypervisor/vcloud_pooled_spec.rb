require 'spec_helper'

module Beaker
  describe VcloudPooled do

    before :each do
      vms = make_hosts()
      MockVsphereHelper.set_config( fog_file_contents )
      MockVsphereHelper.set_vms( vms )
     stub_const( "VsphereHelper", MockVsphereHelper )
     stub_const( "Net", MockNet )
      allow( JSON ).to receive( :parse ) do |arg|
        arg
      end
      allow( Socket ).to receive( :getaddrinfo ).and_return( true )
    end

    describe '#get_template_url' do

      it 'works returns the valid url when passed valid pooling_api and template name' do
        vcloud = Beaker::VcloudPooled.new( make_hosts, make_opts )
        uri = vcloud.get_template_url("http://pooling.com", "template")
        expect( uri ).to be === "http://pooling.com/vm/template"
      end
      
      it 'adds a missing scheme to a given URL' do
        vcloud = Beaker::VcloudPooled.new( make_hosts, make_opts )
        uri = vcloud.get_template_url("pooling.com", "template")
        expect( URI.parse(uri).scheme ).to_not be === nil
      end

      it 'raises an error on an invalid pooling api url' do
        vcloud = Beaker::VcloudPooled.new( make_hosts, make_opts )
        expect{ vcloud.get_template_url("pooling###   ", "template")}.to raise_error ArgumentError
      end

      it 'raises an error on an invalide template name' do
        vcloud = Beaker::VcloudPooled.new( make_hosts, make_opts )
        expect{ vcloud.get_template_url("pooling.com", "t!e&m*p(l\\a/t e")}.to raise_error ArgumentError
      end
      
    end

    describe "#provision" do

      it 'provisions hosts from the pool' do 

        vcloud = Beaker::VcloudPooled.new( make_hosts, make_opts )
        allow( vcloud ).to receive( :require ).and_return( true )
        allow( vcloud ).to receive( :sleep ).and_return( true )
        vcloud.provision

        hosts = vcloud.instance_variable_get( :@hosts )
        hosts.each do | host |
          expect( host['vmhostname'] ).to be === 'pool'
        end
        
      end

    end

    describe "#cleanup" do

      it "cleans up hosts in the pool" do
        MockVsphereHelper.powerOn

        vcloud = Beaker::VcloudPooled.new( make_hosts, make_opts )
        allow( vcloud ).to receive( :require ).and_return( true )
        allow( vcloud ).to receive( :sleep ).and_return( true )
        vcloud.provision
        vcloud.cleanup

        hosts = vcloud.instance_variable_get( :@hosts )
        hosts.each do | host |
          name = host.name
          vm = MockVsphereHelper.find_vm( name )
          expect( vm.runtime.powerState ).to be === "poweredOn" #handed back to the pool, stays on
        end
      end


    end

  end

end
