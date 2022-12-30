require 'spec_helper'

module PSWindows
  describe Host do
    let(:options)  { @options ? @options : {} }
    let(:platform) {
      if @platform
        { :platform => Beaker::Platform.new( @platform) }
      else
        { :platform => Beaker::Platform.new( 'windows-vers-arch-extra' ) }
      end
    }
    let(:host)    {
      opts = options.merge(platform)
      opts[:is_cygwin] = false
      make_host( 'name', opts )
    }

    describe '#external_copy_base' do
      it 'returns previously calculated value if set' do
        external_copy_base_before = host.instance_variable_get( :@external_copy_base )
        test_value = :testn8391
        host.instance_variable_set( :@external_copy_base, test_value )

        expect( host ).not_to receive( :execute )
        expect( host.external_copy_base ).to be === test_value
        host.instance_variable_set( :@external_copy_base, external_copy_base_before )
      end

      it 'calls the correct command if unset' do
        expect( host ).to receive( :execute ).with( /^for\ .*ALLUSERSPROFILE.*\%\~I$/ )
        host.external_copy_base
      end
    end
  end
end
