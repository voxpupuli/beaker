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

    describe '#add_tags' do
      let(:vmpooler) { Beaker::Vmpooler.new(make_hosts({:host_tags => {'test_tag' => 'test_value'}}), make_opts) }

      it 'merges tags correctly' do
        vmpooler.instance_eval {
          @options = @options.merge({:project => 'vmpooler-spec'})
        }
        host          = vmpooler.instance_variable_get(:@hosts)[0]
        merged_tags   = vmpooler.add_tags(host)
        expected_hash = {
            test_tag:       'test_value',
            beaker_version: Beaker::Version::STRING,
            project:        'vmpooler-spec'
        }
        expect(merged_tags).to include(expected_hash)
      end
    end

    describe '#disk_added?' do
      let(:vmpooler) { Beaker::Vmpooler.new(make_hosts, make_opts) }
      let(:response_hash_no_disk) {
        {
          "ok" => "true",
          "hostname" => {
            "template"=>"redhat-7-x86_64",
            "domain"=>"delivery.puppetlabs.net"
          }
        }
      }
      let(:response_hash_disk) {
        {
          "ok" => "true",
          "hostname" => {
            "disk" => [
              '+16gb',
              '+8gb'
            ],
            "template"=>"redhat-7-x86_64",
            "domain"=>"delivery.puppetlabs.net"
          }
        }
      }
      it 'returns false when there is no disk' do
        host = response_hash_no_disk['hostname']
        expect(vmpooler.disk_added?(host, "8", 0)).to be(false)
      end

      it 'returns true when there is a disk' do
        host = response_hash_disk["hostname"]
        expect(vmpooler.disk_added?(host, "16", 0)).to be(true)
        expect(vmpooler.disk_added?(host, "8", 1)).to be(true)
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

      it 'raises an error when a host template is not found in returned json' do
        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )

        allow( vmpooler ).to receive( :require ).and_return( true )
        allow( vmpooler ).to receive( :sleep ).and_return( true )
        allow( vmpooler ).to receive( :get_host_info ).and_return( nil )

        expect {
          vmpooler.provision
        }.to raise_error( RuntimeError,
          /Vmpooler\.provision - requested VM templates \[.*\,.*\,.*\] not available/
        )
      end

      it 'repeats asking only for failed hosts' do
        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )

        allow( vmpooler ).to receive( :require ).and_return( true )
        allow( vmpooler ).to receive( :sleep ).and_return( true )
        allow( vmpooler ).to receive( :get_host_info ).with(
          anything, "vm1_has_a_template" ).and_return( nil )
        allow( vmpooler ).to receive( :get_host_info ).with(
          anything, "vm2_has_a_template" ).and_return( 'y' )
        allow( vmpooler ).to receive( :get_host_info ).with(
          anything, "vm3_has_a_template" ).and_return( 'y' )

        expect {
          vmpooler.provision
        }.to raise_error( RuntimeError,
          /Vmpooler\.provision - requested VM templates \[[^\,]*\] not available/
        ) # should be only one item in the list, no commas
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

      it 'continues without credentials when there are formatting errors in the fog file' do
        data = { "'default'" => { :vmpooler_token => "b2wl8prqe6ddoii70md" } }

        allow_any_instance_of( Beaker::Vmpooler ).to \
          receive(:read_fog_file).and_return(data)

        logger = double('logger')
      
        expect(logger).to receive(:warn).with(/is missing a :default section with a :vmpooler_token value/)
        make_opts = {:logger => logger}

        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )
        expect( vmpooler.credentials ).to be == { }
      end

      it 'throws a TypeError and continues without credentials when there are syntax errors in the fog file' do
        data = "'default'\n  :vmpooler_token: z2wl8prqe0ddoii70ad"

        allow( File ).to receive( :open ).and_yield( StringIO.new(data)  )
        logger = double('logger')
      
        expect(logger).to receive(:warn).with(/TypeError: .* has invalid syntax/)
        make_opts = {:logger => logger}

        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )
        
        expect( vmpooler.credentials ).to be == { }
      end

      it 'throws a Psych::SyntaxError and continues without credentials when there are syntax errors in the fog file' do

        data = ";default;\n  :vmpooler_token: z2wl8prqe0ddoii707d"

        allow( File ).to receive( :open ).and_yield( StringIO.new(data)  )

        logger = double('logger')
      
        expect(logger).to receive(:warn).with(/Psych::SyntaxError: .* invalid syntax/)
        make_opts = {:logger => logger}

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
