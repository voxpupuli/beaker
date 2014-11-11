require 'spec_helper'

module Beaker
  describe Vcloud do

    before :each do
      MockVsphereHelper.set_config( fog_file_contents )
      MockVsphereHelper.set_vms( make_hosts() )
     stub_const( "VsphereHelper", MockVsphereHelper )
     stub_const( "Net", MockNet )
      json = double( 'json' )
      allow( json ).to receive( :parse ) do |arg| 
        arg
      end
     stub_const( "JSON", json )
      allow( Socket ).to receive( :getaddrinfo ).and_return( true )
    end

    describe "#provision" do

      it 'provisions hosts and add them to the pool' do
        MockVsphereHelper.powerOff

        opts = make_opts
        opts[:pooling_api] = nil

        vcloud = Beaker::Vcloud.new( make_hosts, opts )
        allow( vcloud ).to receive( :require ).and_return( true )
        allow( vcloud ).to receive( :sleep ).and_return( true )
        vcloud.provision

        hosts = vcloud.instance_variable_get( :@hosts )
        hosts.each do | host |
          name = host['vmhostname']
          vm = MockVsphereHelper.find_vm( name )
          expect( vm.toolsRunningStatus ).to be === "guestToolsRunning"
        end

      end

    end

    describe "#cleanup" do

      it "cleans up hosts not in the pool" do
        MockVsphereHelper.powerOn

        opts = make_opts
        opts[:pooling_api] = nil

        vcloud = Beaker::Vcloud.new( make_hosts, opts )
        allow( vcloud ).to receive( :require ).and_return( true )
        allow( vcloud ).to receive( :sleep ).and_return( true )
        vcloud.provision
        vcloud.cleanup

        hosts = vcloud.instance_variable_get( :@hosts )
        vm_names = hosts.map {|h| h['vmhostname'] }.compact
        vm_names.each do | name |
          vm = MockVsphereHelper.find_vm( name )
          expect( vm.runtime.powerState ).to be === "poweredOff"
        end

      end

    end

  end

end
