require 'spec_helper'

module Beaker
  describe Windows::File do
    let(:user) { 'someuser' }
    let(:group) { 'somegroup' }
    let(:path) { 'C:\Foo\Bar' }
    let(:newpath) { '/Foo/Bar' }
    let(:host)    { make_host( 'name', { :platform => 'windows' } ) }


    describe '#chown' do
      it 'calls cygpath first' do
        expect( host ).to receive( :execute ).with( "cygpath -u #{path}" )
        expect( host ).to receive( :execute ).with( /chown/ )

        host.chown( user, path )
      end

      it 'passes cleaned path to super' do
        allow_any_instance_of( Windows::Host ).to receive( :execute ).with( /cygpath/ ).and_return( newpath )
        expect_any_instance_of( Unix::Host ).to receive( :chown ).with( user, newpath , true)

        host.chown( user, path, true )
      end
    end

    describe '#chgrp' do
      it 'calls cygpath first' do
        expect( host ).to receive( :execute ).with( "cygpath -u #{path}" ).and_return( path )
        expect( host ).to receive( :execute ).with( "chgrp #{group} #{path}" )

        host.chgrp( group, path )
      end

      it 'passes cleaned path to super' do
        allow_any_instance_of( Windows::Host ).to receive( :execute ).with( /cygpath/ ).and_return( newpath )
        expect_any_instance_of( Unix::Host ).to receive( :chgrp ).with( group, newpath , true)

        host.chgrp( group, path, true )
      end
    end

    describe '#ls_ld' do
      let(:result) { Beaker::Result.new(host, 'ls') }

      it 'calls cygpath first' do
        expect( host ).to receive( :execute ).with( "cygpath -u #{path}" ).and_return( path )
        expect( host ).to receive( :execute ).with( "ls -ld #{path}" )

        host.ls_ld( path )
      end
    end

    describe "#scp_to" do
      let(:path) { 'C:\Windows' }

      it 'replaces backslashes with ??? when using BitVise and cmd' do
        allow(host).to receive(:determine_ssh_server).and_return(:bitvise)
        expect(host.scp_path(path)).to eq('C:\Windows')
      end

      it 'replaces backslashes with forward slashes when using BitVise and powershell' do
        host = make_host('name', platform: 'windows', is_cygwin: false)
        allow(host).to receive(:determine_ssh_server).and_return(:bitvise)
        expect(host.scp_path(path)).to eq('C:/Windows')
      end

      it 'leaves backslashes as is when using cygwin' do
        allow(host).to receive(:determine_ssh_server).and_return(:openssh)
        expect(host.scp_path(path)).to eq('C:\Windows')
      end

      it 'replace backslashes with forward slashes when using Win32-OpenSSH' do
        allow(host).to receive(:determine_ssh_server).and_return(:win32_openssh)
        expect(host.scp_path(path)).to eq('C:/Windows')
      end

      it 'raises if the server can not be recognized' do
        allow(host).to receive(:determine_ssh_server).and_return(:unknown)
        expect {
          host.scp_path(path)
        }.to raise_error(ArgumentError, "windows/file.rb:scp_path: ssh server not recognized: 'unknown'")
      end
    end
  end
end
