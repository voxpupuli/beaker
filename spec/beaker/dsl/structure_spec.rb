require 'spec_helper'

class ClassMixedWithDSLStructure
  include Beaker::DSL::Structure
end

describe ClassMixedWithDSLStructure do
  include Beaker::DSL::Assertions
  let(:logger) { double }
  describe '#step' do
    it 'requires a name' do
      expect { subject.step do; end }.to raise_error ArgumentError
    end

    it 'notifies the logger' do
      expect( subject ).to receive( :logger ).and_return( logger )
      expect( logger ).to receive( :notify )
      subject.step 'blah'
    end

    it 'yields if a block is given' do
      expect( subject ).to receive( :logger ).and_return( logger )
      expect( logger ).to receive( :notify )
      expect( subject ).to receive( :foo )
      subject.step 'blah' do
        subject.foo
      end
    end
  end

  describe '#test_name' do
    it 'requires a name' do
      expect { subject.test_name do; end }.to raise_error ArgumentError
    end

    it 'notifies the logger' do
      expect( subject ).to receive( :logger ).and_return( logger )
      expect( logger ).to receive( :notify )
      subject.test_name 'blah'
    end

    it 'yields if a block is given' do
      expect( subject ).to receive( :logger ).and_return( logger )
      expect( logger ).to receive( :notify )
      expect( subject ).to receive( :foo )
      subject.test_name 'blah' do
        subject.foo
      end
    end
  end

  describe '#teardown' do
    it 'append a block to the @teardown var' do
      teardown_array = double
      subject.instance_variable_set :@teardown_procs, teardown_array
      block = lambda { 'blah' }
      expect( teardown_array ).to receive( :<< ).with( block )
      subject.teardown &block
    end
  end

  describe '#expect_failure' do
    it 'passes when a MiniTest assertion is raised' do
      expect( subject ).to receive( :logger ).and_return( logger )
      expect( logger ).to receive( :notify )
      block = lambda { assert_equal('1', '2', '1 should not equal 2') }
      expect{ subject.expect_failure 'this is an expected failure', &block }.to_not raise_error
    end

    it 'passes when a Beaker assertion is raised' do
      expect( subject ).to receive( :logger ).and_return( logger )
      expect( logger ).to receive( :notify )
      block = lambda { assert_no_match('1', '1', '1 and 1 should not match') }
      expect{ subject.expect_failure 'this is an expected failure', &block }.to_not raise_error
    end

    it 'fails when a non-Beaker, non-MiniTest assertion is raised' do
      block = lambda { raise 'not a Beaker or MiniTest error' }
      expect{ subject.expect_failure 'this has a non-Beaker, non-MiniTest exception', &block }.to raise_error(RuntimeError, /not a Beaker or MiniTest error/)
    end

    it 'fails when no assertion is raised' do
      block = lambda { assert_equal('1', '1', '1 should equal 1') }
      expect{ subject.expect_failure 'this has no failure', &block }.to raise_error(RuntimeError, /An assertion was expected to fail, but passed/)
    end
  end

  describe 'confine' do
    let(:logger) { double.as_null_object }
    before do
      allow( subject ).to receive( :logger ).and_return( logger )
    end

    it 'skips the test if there are no applicable hosts' do
      allow( subject ).to receive( :hosts ).and_return( [] )
      allow( subject ).to receive( :hosts= )
      expect( logger ).to receive( :warn )
      expect( subject ).to receive( :skip_test ).
        with( 'No suitable hosts found' )

      subject.confine( :to, {} )
    end

    it 'raises when given mode is not :to or :except' do
      allow( subject ).to receive( :hosts )
      allow( subject ).to receive( :hosts= )

      expect {
        subject.confine( :regardless, {:thing => 'value'} )
      }.to raise_error( 'Unknown option regardless' )
    end

    it 'rejects hosts that do not meet simple hash criteria' do
      hosts = [ {'thing' => 'foo'}, {'thing' => 'bar'} ]

      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :hosts= ).
        with( [ {'thing' => 'foo'} ] )

      subject.confine :to, :thing => 'foo'
    end

    it 'rejects hosts that match a list of criteria' do
      hosts = [ {'thing' => 'foo'}, {'thing' => 'bar'}, {'thing' => 'baz'} ]

      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :hosts= ).
        with( [ {'thing' => 'bar'} ] )

      subject.confine :except, :thing => ['foo', 'baz']
    end

    it 'rejects hosts when a passed block returns true' do
      host1 = {'platform' => 'solaris'}
      host2 = {'platform' => 'solaris'}
      host3 = {'platform' => 'windows'}
      ret1 = (Struct.new('Result1', :stdout)).new(':global')
      ret2 = (Struct.new('Result2', :stdout)).new('a_zone')
      hosts = [ host1, host2, host3 ]

      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :on ).
        with( host1, '/sbin/zonename' ).
        and_return( ret1 )
      expect( subject ).to receive( :on ).
        with( host1, '/sbin/zonename' ).
        and_return( ret2 )

      expect( subject ).to receive( :hosts= ).with( [ host1 ] )

      subject.confine :to, :platform => 'solaris' do |host|
        subject.on( host, '/sbin/zonename' ).stdout =~ /:global/
      end
    end
  end

  describe '#select_hosts' do
    let(:logger) { double.as_null_object }
    before do
      allow( subject ).to receive( :logger ).and_return( logger )
    end

    it 'it returns an empty array if there are no applicable hosts' do
      hosts = [ {'thing' => 'foo'}, {'thing' => 'bar'} ]

      expect(subject.select_hosts( {'thing' => 'nope'}, hosts )).to be == []
    end

    it 'selects hosts that match a list of criteria' do
      hosts = [ {'thing' => 'foo'}, {'thing' => 'bar'}, {'thing' => 'baz'} ]

      expect(subject.select_hosts( {:thing => ['foo', 'baz']}, hosts )).to be == [ {'thing' => 'foo'}, {'thing' => 'baz'} ]
    end

    it 'selects hosts when a passed block returns true' do
      host1 = {'platform' => 'solaris1'}
      host2 = {'platform' => 'solaris2'}
      host3 = {'platform' => 'windows'}
      ret1 = double('result1')
      allow( ret1 ).to receive( :stdout ).and_return(':global')
      ret2 = double('result2')
      allow( ret2 ).to receive( :stdout ).and_return('a_zone')
      hosts = [ host1, host2, host3 ]
      expect( subject ).to receive( :hosts ).and_return( hosts )

      expect( subject ).to receive( :on ).with( host1, '/sbin/zonename' ).once.and_return( ret1 )
      expect( subject ).to receive( :on ).with( host2, '/sbin/zonename' ).once.and_return( ret2 )

      selected_hosts = subject.select_hosts 'platform' => 'solaris' do |host|
                             subject.on(host, '/sbin/zonename').stdout =~ /:global/
      end
      expect( selected_hosts ).to be == [ host1 ]
    end
  end
end
