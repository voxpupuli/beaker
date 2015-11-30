require 'spec_helper'

class ClassMixedWithDSLStructure
  include Beaker::DSL
end

describe ClassMixedWithDSLStructure do
  include Beaker::DSL::Assertions

  let (:logger) { double }
  let (:metadata) { @metadata ||= {} }

  before :each do
    allow( subject ).to receive(:metadata).and_return(metadata)
  end

  describe '#step' do
    it 'requires a name' do
      expect { subject.step do; end }.to raise_error ArgumentError
    end

    it 'notifies the logger' do
      allow( subject ).to receive( :set_current_step_name )
      expect( subject ).to receive( :logger ).and_return( logger )
      expect( logger ).to receive( :notify )
      subject.step 'blah'
    end

    it 'yields if a block is given' do
      expect( subject ).to receive( :logger ).and_return( logger ).exactly(3).times
      allow(  subject ).to receive( :set_current_step_name )
      expect( logger ).to receive( :step_in )
      expect( logger ).to receive( :step_out )
      expect( logger ).to receive( :notify )
      expect( subject ).to receive( :foo )
      subject.step 'blah' do
        subject.foo
      end
    end

    it 'sets the metadata' do
      allow( subject ).to receive( :logger ).and_return( logger )
      allow( logger ).to receive( :notify )
      step_name = 'pierceBrosnanTests'
      subject.step step_name
      expect( metadata[:step][:name] ).to be === step_name
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
      expect( subject ).to receive( :logger ).and_return( logger ).exactly(3).times
      expect( logger ).to receive( :notify )
      expect( logger ).to receive( :step_in )
      expect( logger ).to receive( :step_out )
      expect( subject ).to receive( :foo )
      subject.test_name 'blah' do
        subject.foo
      end
    end

    it 'sets the metadata' do
      allow( subject ).to receive( :logger ).and_return( logger )
      allow( logger ).to receive( :notify )
      test_name = '15-05-08\'s weather is beautiful'
      subject.test_name test_name
      expect( metadata[:case][:name] ).to be === test_name
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

    it ':to - uses a provided host subset when no criteria is provided' do
      subset = ['host1', 'host2']
      hosts = subset.dup << 'host3'
      allow( subject ).to receive( :hosts ).and_return(hosts).twice
      expect( subject ).to receive( :hosts= ).with( subset )
      subject.confine :to, {}, subset
    end

    it ':except - excludes provided host subset when no criteria is provided' do
      subset = ['host1', 'host2']
      hosts = subset.dup << 'host3'
      allow( subject ).to receive( :hosts ).and_return(hosts).twice
      expect( subject ).to receive( :hosts= ).with( hosts - subset )
      subject.confine :except, {}, subset
    end

    it 'raises when given mode is not :to or :except' do
      hosts = ['host1', 'host2']
      allow( subject ).to receive( :hosts ).and_return(hosts)
      allow( subject ).to receive( :hosts= )

      expect {
        subject.confine( :regardless, {:thing => 'value'} )
      }.to raise_error( 'Unknown option regardless' )
    end

    it 'rejects hosts that do not meet simple hash criteria' do
      hosts = [ {'thing' => 'foo'}, {'thing' => 'bar'} ]

      expect( subject ).to receive( :hosts ).and_return( hosts ).twice
      expect( subject ).to receive( :hosts= ).
        with( [ {'thing' => 'foo'} ] )

      subject.confine :to, :thing => 'foo'
    end

    it 'rejects hosts that match a list of criteria' do
      hosts = [ {'thing' => 'foo'}, {'thing' => 'bar'}, {'thing' => 'baz'} ]

      expect( subject ).to receive( :hosts ).and_return( hosts ).twice
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

      expect( subject ).to receive( :hosts ).and_return( hosts ).twice
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

    it 'doesn\'t corrupt the global hosts hash when confining from a subset of hosts' do
      host1 = {'platform' => 'solaris', :roles => ['master']}
      host2 = {'platform' => 'solaris', :roles => ['agent']}
      host3 = {'platform' => 'windows', :roles => ['agent']}
      hosts = [ host1, host2, host3 ]
      agents = [ host2, host3 ]

      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :hosts= ).with( [  host2, host1 ] )
      confined_hosts = subject.confine :except, {:platform => 'windows'}, agents
      expect( confined_hosts ).to be === [ host2, host1 ]
    end

    it 'can apply multiple confines correctly' do
      host1 = {'platform' => 'solaris', :roles => ['master']}
      host2 = {'platform' => 'solaris', :roles => ['agent']}
      host3 = {'platform' => 'windows', :roles => ['agent']}
      host4 = {'platform' => 'fedora', :roles => ['agent']}
      host5 = {'platform' => 'fedora', :roles => ['agent']}
      hosts = [ host1, host2, host3, host4, host5 ]
      agents = [ host2, host3, host4, host5 ]

      expect( subject ).to receive( :hosts ).and_return( hosts ).exactly(3).times
      expect( subject ).to receive( :hosts= ).with( [  host1, host2, host4, host5 ] )
      hosts = subject.confine :except, {:platform => 'windows'}
      expect( hosts ).to be === [ host1, host2, host4, host5  ]
      expect( subject ).to receive( :hosts= ).with( [  host4, host5, host1 ] )
      hosts = subject.confine :to, {:platform => 'fedora'}, agents
      expect( hosts ).to be === [ host4, host5, host1 ]
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

  describe '#tag' do
    let ( :tag_includes ) { @tag_includes || [] }
    let ( :tag_excludes ) { @tag_excludes || [] }
    let ( :options )      {
      opts = Beaker::Options::OptionsHash.new
      opts[:tag_includes] = tag_includes
      opts[:tag_excludes] = tag_excludes
      opts
    }

    it 'sets tags on the TestCase\'s metadata object' do
      subject.instance_variable_set(:@options, options)
      tags = ['pants', 'jayjay', 'moguely']
      subject.tag(*tags)
      expect( metadata[:case][:tags] ).to be === tags
    end

    it 'lowercases the tags' do
      subject.instance_variable_set(:@options, options)
      tags_upper = ['pANTs', 'jAYJAy', 'moGUYly']
      tags_lower = tags_upper.map(&:downcase)
      subject.tag(*tags_upper)
      expect( metadata[:case][:tags] ).to be === tags_lower
    end

    it 'skips the test if any of the requested tags isn\'t included in this test' do
      test_tags = ['pants', 'jayjay', 'moguely']
      @tag_includes = test_tags.compact.push('needed_tag_not_in_test')
      subject.instance_variable_set(:@options, options)

      allow( subject ).to receive( :path )
      expect( subject ).to receive( :skip_test )
      subject.tag(*test_tags)
    end

    it 'runs the test if all requested tags are included in this test' do
      @tag_includes = ['pants_on_head', 'jayjay_jayjay', 'mo']
      test_tags = @tag_includes.compact.push('extra_asdf')
      subject.instance_variable_set(:@options, options)

      allow( subject ).to receive( :path )
      expect( subject ).to receive( :skip_test ).never
      subject.tag(*test_tags)
    end

    it 'skips the test if any of the excluded tags are included in this test' do
      test_tags = ['ports', 'jay_john_mary', 'mog_the_dog']
      @tag_excludes = [test_tags[0]]
      subject.instance_variable_set(:@options, options)

      allow( subject ).to receive( :path )
      expect( subject ).to receive( :skip_test )
      subject.tag(*test_tags)
    end

    it 'runs the test if none of the excluded tags are included in this test' do
      @tag_excludes = ['pants_on_head', 'jayjay_jayjay', 'mo']
      test_tags     = ['pants_at_head', 'jayj00_jayjay', 'motly_crew']
      subject.instance_variable_set(:@options, options)

      allow( subject ).to receive( :path )
      expect( subject ).to receive( :skip_test ).never
      subject.tag(*test_tags)
    end

  end
end
