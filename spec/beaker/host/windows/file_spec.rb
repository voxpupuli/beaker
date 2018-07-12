require 'spec_helper'

module Beaker
  describe Windows::File do
    let (:user) { 'someuser' }
    let (:group) { 'somegroup' }
    let (:path) { 'C:\Foo\Bar' }
    let (:newpath) { '/Foo/Bar' }
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
  end
end
