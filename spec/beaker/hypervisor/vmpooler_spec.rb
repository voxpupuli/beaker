require 'spec_helper'

module Beaker
  describe Vmpooler do

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
      allow_any_instance_of( Beaker::Vmpooler ).to \
        receive(:load_credentials).and_return(fog_file_contents)
    end

    describe '#get_template_url' do

      it 'works returns the valid url when passed valid pooling_api and template name' do
        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )
        uri = vmpooler.get_template_url("http://pooling.com", "template")
        expect( uri ).to be === "http://pooling.com/vm/template"
      end

      it 'adds a missing scheme to a given URL' do
        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )
        uri = vmpooler.get_template_url("pooling.com", "template")
        expect( URI.parse(uri).scheme ).to_not be === nil
      end

      it 'raises an error on an invalid pooling api url' do
        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )
        expect{ vmpooler.get_template_url("pooling###   ", "template")}.to raise_error ArgumentError
      end

      it 'raises an error on an invalide template name' do
        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )
        expect{ vmpooler.get_template_url("pooling.com", "t!e&m*p(l\\a/t e")}.to raise_error ArgumentError
      end
    end

    describe "#provision" do

      it 'provisions hosts from the pool' do
        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )
        allow( vmpooler ).to receive( :require ).and_return( true )
        allow( vmpooler ).to receive( :sleep ).and_return( true )
        vmpooler.provision

        hosts = vmpooler.instance_variable_get( :@hosts )
        hosts.each do | host |
          expect( host['vmhostname'] ).to be === 'pool'
        end
      end
    end

    describe "#cleanup" do

      it "cleans up hosts in the pool" do
        MockVsphereHelper.powerOn

        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )
        allow( vmpooler ).to receive( :require ).and_return( true )
        allow( vmpooler ).to receive( :sleep ).and_return( true )
        vmpooler.provision
        vmpooler.cleanup

        hosts = vmpooler.instance_variable_get( :@hosts )
        hosts.each do | host |
          name = host.name
          vm = MockVsphereHelper.find_vm( name )
          expect( vm.runtime.powerState ).to be === "poweredOn" #handed back to the pool, stays on
        end
      end
    end
  end

  describe Vmpooler do

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

    describe "#load_credentials" do

      it 'continues without credentials when fog file is missing' do
        allow_any_instance_of( Beaker::Vmpooler ).to \
          receive(:read_fog_file).and_raise(Errno::ENOENT.new)

        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )
        expect( vmpooler.credentials ).to be == {}
      end

      it 'continues without credentials when fog file is empty' do
        allow_any_instance_of( Beaker::Vmpooler ).to \
          receive(:read_fog_file).and_return(false)

        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )
        expect( vmpooler.credentials ).to be == {}
      end

      it 'continues without credentials when fog file contains no :default section' do
        data = { :some => { :other => :data } }

        allow_any_instance_of( Beaker::Vmpooler ).to \
          receive(:read_fog_file).and_return(data)

        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )
        expect( vmpooler.credentials ).to be == { }
      end

      it 'continues without credentials when fog file :default section has no :vmpooler_token' do
        data = { :default => { :something_else => "TOKEN" } }

        allow_any_instance_of( Beaker::Vmpooler ).to \
          receive(:read_fog_file).and_return(data)

        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )
        expect( vmpooler.credentials ).to be == { }
      end

      it 'stores vmpooler token when found in fog file' do
        data = { :default => { :vmpooler_token => "TOKEN" } }

        allow_any_instance_of( Beaker::Vmpooler ).to \
          receive(:read_fog_file).and_return(data)

        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )
        expect( vmpooler.credentials ).to be == { :vmpooler_token => "TOKEN" }
      end
    end
  end
end
