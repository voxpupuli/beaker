require 'spec_helper'

module Beaker
  describe Fusion do
    let( :fusion ) { Beaker::Fusion.new( @hosts, make_opts ) }

    before :each do
     stub_const( "Fission::VM", true )
      @hosts = make_hosts({:ip => nil})
      MockFission.presets( @hosts )
      allow_any_instance_of( Fusion ).to receive( :require ).with( 'fission' ).and_return( true )
      fusion.instance_variable_set( :@fission, MockFission )
    end

    it "can interoperate with the fission library to provision hosts"  do
      allow( fusion ).to receive( :try_ssh_connection )
      fusion.provision
    end

    it "raises an error if unknown snapshot name is used" do
      @hosts[0][:snapshot] = 'unknown'
      expect{ fusion.provision }.to raise_error
    end

    it 'raises an error if snapshots is nil' do
      MockFissionVM.set_snapshots(nil)
      expect{ fusion.provision }.to raise_error(/No snapshots available/)
    end

    it 'raises an error if snapshots are empty' do
      MockFissionVM.set_snapshots([])
      expect{ fusion.provision }.to raise_error(/No snapshots available/)
    end

    it 'host fails init with nil snapshot' do
      @hosts[0][:snapshot] = nil
      expect{ Beaker::Fusion.new( @hosts, make_opts) }.to raise_error(/specify a snapshot/)
    end

    context 'connection can be made by host.name' do
      before :each do
        allow( fusion ).to receive( :try_ssh_connection )
      end

      it 'does not set host[:ip] if a connection can be made my host.name' do
        fusion.provision
        @hosts.each do |host|
          expect(host['ip']).to eql(nil)
        end
      end
    end

    context 'if connection cannot be made by host.name,' do
      before :each do
        allow( fusion ).to receive( :try_ssh_connection ).with(/^\d+\.\d+\.\d+\.\d+$/, anything, anything).and_return(true)
        allow( fusion ).to receive( :try_ssh_connection ).with(/^[a-z]/, anything, anything).and_raise(SocketError)
      end

      it 'then intropects IP address and sets host[:ip]' do
        fusion.provision
        @hosts.each do |host|
          expect(host['ip']).not_to eql(nil)
          expect(host['ip']).to eql(MockFission.all.data.find{|h| h.name == host.name}.network_info.data.first[1]['ip_address'])
        end
      end

      it 'then host fails init if ip cannot be introspected' do
        allow_any_instance_of( MockFissionVM ).to receive( :network_info ).and_return( Response.new(0,'',{'eth0' => {'ip_address' => nil}}))
        expect{ fusion.provision }.to raise_error(/ip address is unavailable/)
      end

      it 'then sets host dns_name to instance.dns_name' do
        expect(fusion).to receive(:hack_etc_hosts).with(@hosts, anything).once
        fusion.provision
      end
    end

  end

end
