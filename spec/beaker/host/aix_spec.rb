require 'spec_helper'

module Aix
  describe Host do
    let(:options)  { @options ? @options : {} }
    let(:platform) {
      if @platform
        { :platform => Beaker::Platform.new( @platform) }
      else
        { :platform => Beaker::Platform.new( 'aix-vers-arch-extra' ) }
      end
    }
    let(:host)    { make_host( 'name', options.merge(platform) ) }

    describe '#ssh_service_restart' do
      it 'invokes the correct commands on the host' do
        expect( Beaker::Command ).to receive( :new ).with( 'stopsrc -g ssh'  ).once.ordered
        expect( Beaker::Command ).to receive( :new ).with( 'startsrc -g ssh' ).once.ordered
        host.ssh_service_restart
      end
    end

    describe '#ssh_permit_user_environment' do
      it 'calls echo to set PermitUserEnvironment' do
        expect( Beaker::Command ).to receive( :new ).with( /^echo\ / ).once.ordered
        allow( host ).to receive( :ssh_service_restart )
        host.ssh_permit_user_environment
      end

      it 'uses the correct ssh config file' do
        expect( Beaker::Command ).to receive( :new ).with( /#{Regexp.escape(' >> /etc/ssh/sshd_config')}$/ ).once
        allow( host ).to receive( :ssh_service_restart )
        host.ssh_permit_user_environment
      end
    end

    describe '#reboot' do
      it 'invokes the correct command on the host' do
        expect( Beaker::Command ).to receive( :new ).with( 'shutdown -Fr' ).once
        host.reboot
      end
    end

    describe '#get_ip' do
      it 'invokes the correct command on the host' do
        expect( host ).to receive( :execute ).with( /^ifconfig\ \-a\ inet\|\ / ).once.and_return( '' )
        host.get_ip
      end
    end
  end
end