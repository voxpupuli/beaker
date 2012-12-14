require 'spec_helper'

module PuppetAcceptance
  describe TestCase do
    let(:host_param)    { @host_param || Array.new }
    let(:logger_param)  { double('logger').as_null_object }
    let(:config_param)  { Hash.new }
    let(:options_param) { Hash.new }
    let(:path_param)    { '/file/path/string' }
    let(:test_case) do
      TestCase.new( host_param, logger_param, config_param, options_param, path_param )
    end

    it('initializes') { expect( test_case ).to be_an_instance_of( TestCase ) }

    describe 'confine' do
      it 'skips the test if there are no applicable hosts' do
        logger_param.should_receive( :warn )
        test_case.should_receive( :skip_test ).
          with( 'No suitable hosts found' )
        test_case.confine( :to, {} )
      end

      it 'raises when given mode is not :to or :except' do
        expect {
          test_case.confine( :regardless, {:thing => 'value'} )
        }.to raise_error( 'Unknown option regardless' )
      end

      it 'rejects hosts that do not meet simple hash criteria' do
        @host_param = [ {'thing' => 'foo'}, {'thing' => 'bar'} ]
        test_case.confine :to, :thing => 'foo'
        expect( test_case.hosts ).to be == [ {'thing' => 'foo'} ]
      end

      it 'rejects hosts that match a list of criteria' do
        @host_param = [ {'thing' => 'foo'}, {'thing' => 'bar'}, {'thing' => 'baz'} ]
        test_case.confine :except, :thing => ['foo', 'baz']
        expect( test_case.hosts ).to be == [ {'thing' => 'bar'} ]
      end

      it 'rejects hosts when a passed block returns true' do
        host1 = {'platform' => 'solaris'}
        host2 = {'platform' => 'solaris'}
        host3 = {'platform' => 'windows'}
        ret1 = (Struct.new('Result1', :stdout)).new(':global')
        ret2 = (Struct.new('Result2', :stdout)).new('a_zone')
        @host_param = [ host1, host2, host3 ]

        test_case.should_receive( :on ).
          with( host1, '/sbin/zonename' ).
          and_return( ret1 )
        test_case.should_receive( :on ).
          with( host1, '/sbin/zonename' ).
          and_return( ret2 )

        test_case.confine :to, :platform => 'solaris' do |host|
          test_case.on( host, '/sbin/zonename' ).stdout =~ /:global/
        end

        expect( test_case.hosts ).to be == [ host1 ]
      end
    end
  end
end
