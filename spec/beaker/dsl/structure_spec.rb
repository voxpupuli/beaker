require 'spec_helper'

class ClassMixedWithDSLStructure
  include Beaker::DSL::Structure
  include Beaker::DSL::Helpers::TestHelpers
end

describe ClassMixedWithDSLStructure do
  include Beaker::DSL::Assertions

  let (:logger) { double }
  let (:metadata) { @metadata ||= {} }

  before :each do
    allow( subject ).to receive(:metadata).and_return(metadata)

    cur_time = 0
    allow( Time ).to receive(:now) do
      _cur_time = cur_time
      cur_time = cur_time + 1
      _cur_time
    end

    steps = 0
    tests = 0
    @timed_node = Tree::TreeNode.new("Root", 0.0)
    subject.instance_variable_set :@timed_node, @timed_node
    constructor = Tree::TreeNode.method(:new)
    allow( Tree::TreeNode ).to receive(:new) do |label, start_time|
      # Ensure proper arguments are passed-in
      expect(label).to be_instance_of(Array)
      expect(label.size).to eql(3)

      kind, uuid, name = label
      expect(kind).to match(/^(?:Step|Test)$/)
      # from the source of SecureRandom.uuid in
      # https://ruby-doc.org/stdlib-1.9.3/libdoc/securerandom/rdoc/SecureRandom.html
      expect(uuid).to match(/^\h{8}-\h{4}-\h{4}-\h{4}-\h{4}\h{8}$/)
      expect(start_time).to eql(cur_time - 1)

      count = kind == "Step" ? steps = steps + 1 : tests = tests + 1
      constructor.call("#{kind} #{count}: #{name}", start_time)
    end
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

    it 'times how long the current step takes, while storing its overall structure' do
      allow( subject ).to receive( :logger ).and_return( logger )
      allow(  subject ).to receive( :set_current_step_name )
      allow( logger ).to receive( :step_in )
      allow( logger ).to receive( :step_out )
      allow( logger ).to receive( :notify )

      subject.step "A" do
        subject.step "B" do
          subject.step "C" do
            subject.step "D" do
            end
          end
        end
        subject.step "E" do
          subject.step "F" do
          end
        end
        subject.step "G" do
        end
      end

      # Readability
      a, b, c, d, e, f, g = ("A".."G").each_with_index.map { |name, ix| "Step #{ix + 1}: #{name}" }
      # This is a map of <Path> -> <Duration>, where <Path> represents the path
      # to a specific node, and <Duration> represents the expected "Duration" of
      # a node
      structure = {
        [a, b, c, d] => 1,
        [a, b, c] => 3,
        [a, b] => 5,
        [a, e, f] => 1,
        [a, e] => 3,
        [a, g] => 1,
        [a] => 13
      }

      # Ensure correct structure is stored. Note that the "duration" of a given
      # node is the total # of times that Time.now has been called since that node's
      # "start time" was recorded.
      structure.each do |path, duration|
        node = path.inject(@timed_node) { |node, child| node[child] }
        expect(node).not_to be_nil
        expect(node.content).to eql(duration)
      end
    end

    context 'when the step fails' do
      it 'marks the current step as a failure, preserves the durations (and structure) of previously successful steps, and skips any impending ones' do
        subject.instance_variable_set :@options, {} 
        allow( subject ).to receive( :logger ).and_return( logger )
        allow(  subject ).to receive( :set_current_step_name )
        allow( logger ).to receive( :step_in )
        allow( logger ).to receive( :step_out )
        allow( logger ).to receive( :notify )

        steps_ran = ""

        expect do
          subject.step "A" do
            subject.step "B" do
              subject.step "C" do
                subject.step "D" do
                  steps_ran << "D"
                end
                steps_ran << "C"
              end
              steps_ran << "B"
            end
            subject.step "E" do
              subject.step "F" do
                steps_ran << "F"
              end
              raise "Fail this step!"
              steps_ran << "E"
            end
            subject.step "G" do
              steps_ran << "G"
            end
          end
        end.to raise_exception("Fail this step!")

        expect(steps_ran).to eql("DCBF")

        a, b, c, d, e, f, g = ("A".."G").each_with_index.map { |name, ix| "Step #{ix + 1}: #{name}" }
        structure = {
          [a, b, c, d] => 1,
          [a, b, c] => 3,
          [a, b] => 5,
          [a, e, f] => 1,
          [a, e] => "X",
          [a] => "X"
        }
        structure.each do |path, duration|
          node = path.inject(@timed_node) { |node, child| node[child] }
          expect(node).not_to be_nil
          expect(node.content).to eql(duration)
        end
      end
    end
  end

  describe '#manual_step' do
    context 'without exec manual test option' do
      let( :options ) { {} }
      it 'throws an error' do
        expect( Readline ).not_to receive( :readline )
        expect { subject.manual_step 'blah' do; end }.to raise_error StandardError
      end
    end

    context 'with exec manual test option' do
      let( :options ) { {exec_manual_tests: nil} }
      it 'requires a name' do
        expect { subject.manual_step do; end }.to raise_error ArgumentError
      end

      it 'notifies the logger' do
        subject.instance_variable_set(:@options, options)
        allow( subject ).to receive( :set_current_step_name )
        expect( subject ).to receive( :logger ).and_return( logger )
        expect( logger ).to receive( :notify )
        allow( Readline ).to receive( :readline ).and_return( 'Y')
        subject.manual_step 'blah'
      end
    end

    context 'with exec manual test option set to true' do
      let( :options ) { {exec_manual_tests: true} }
      it 'requires a name' do
        expect { subject.manual_step do; end }.to raise_error ArgumentError
      end

      it 'pass when user enters Y' do
        subject.instance_variable_set(:@options, options)
        allow( subject ).to receive( :set_current_step_name )
        allow( subject ).to receive( :logger ).and_return( logger )
        allow( logger ).to receive( :notify )
        expect( Readline ).to receive( :readline ).and_return( 'Y')
        subject.manual_step 'blahblah'
      end

      it 'fails when user enters n and uses default error when no message is entered' do
        subject.instance_variable_set(:@options, options)
        allow( subject ).to receive( :set_current_step_name )
        allow( subject ).to receive( :logger ).and_return( logger )
        allow( logger ).to receive( :notify )
        expect( Readline ).to receive( :readline ).and_return('n', 'step failed')
        expect { subject.manual_step 'blah two' do; end }.to raise_error(Beaker::DSL::FailTest, 'step failed')
      end
    end
  end

  describe '#manual_test' do
    context 'without exec manual test option' do
      let( :options ) { {} }
      it 'requires a name' do
        expect { subject.manual_test do; end }.to raise_error ArgumentError
      end

      it 'raises a skip test' do
        subject.instance_variable_set(:@options, options)
        allow( subject ).to receive( :logger ).and_return( logger )
        allow( logger ).to receive( :notify )
        test_name = 'random test name'
        expect { subject.manual_test test_name do; end }.to raise_error Beaker::DSL::SkipTest
      end
    end

    context 'with exec manual test option' do
      let( :options ) { {exec_manual_tests: true} }
      it 'requires a name' do
        expect { subject.manual_test do; end }.to raise_error ArgumentError
      end

      it 'notifies the logger' do
        subject.instance_variable_set(:@options, options)
        expect( subject ).to receive( :logger ).and_return( logger )
        expect( logger ).to receive( :notify )
        subject.manual_test 'blah blah'
      end

      it 'yields if a block is given' do
        subject.instance_variable_set(:@options, options)
        expect( subject ).to receive( :logger ).and_return( logger ).exactly(3).times
        expect( logger ).to receive( :notify )
        expect( logger ).to receive( :step_in )
        expect( logger ).to receive( :step_out )
        expect( subject ).to receive( :foo )
        subject.manual_test 'blah' do
          subject.foo
        end
      end

      it 'sets the metadata' do
        subject.instance_variable_set(:@options, options)
        allow( subject ).to receive( :logger ).and_return( logger )
        allow( logger ).to receive( :notify )
        test_name = 'test is setting metadata yay!'
        subject.manual_test test_name
        expect( metadata[:case][:name] ).to be === test_name
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

    it 'times how long the current test takes, while storing its overall structure' do
      allow( subject ).to receive( :logger ).and_return( logger )
      allow(  subject ).to receive( :set_current_step_name )
      allow( logger ).to receive( :step_in )
      allow( logger ).to receive( :step_out )
      allow( logger ).to receive( :notify )

      subject.test_name "A" do
        subject.test_name "B" do
          subject.test_name "C" do
            subject.test_name "D" do
            end
          end
        end
        subject.test_name "E" do
          subject.test_name "F" do
          end
        end
        subject.test_name "G" do
        end
      end

      # Readability
      a, b, c, d, e, f, g = ("A".."G").each_with_index.map { |name, ix| "Test #{ix + 1}: #{name}" }
      # This is a map of <Path> -> (<Exists?>, <Duration>), where <Path> represents the path
      # to a specific node, <Exists?> indicates if the node exists or not, and <Duration> 
      # represents the expected "Duration" of a node
      structure = {
        [a, b, c, d] => 1,
        [a, b, c] => 3,
        [a, b] => 5,
        [a, e, f] => 1,
        [a, e] => 3,
        [a, g] => 1,
        [a] => 13
      }

      # Ensure correct structure is stored. Note that the "duration" of a given
      # node is the total # of times that Time.now has been called since that node's
      # "start time" was recorded.
      structure.each do |path, duration|
        node = path.inject(@timed_node) { |node, child| node[child] }
        expect(node).not_to be_nil
        expect(node.content).to eql(duration)
      end
    end

    context 'when the test fails' do
      it 'marks the current test as a failure, preserves the durations (and structure) of previously successful tests, and skips any impending ones' do
        subject.instance_variable_set :@options, {} 
        allow( subject ).to receive( :logger ).and_return( logger )
        allow(  subject ).to receive( :set_current_step_name )
        allow( logger ).to receive( :step_in )
        allow( logger ).to receive( :step_out )
        allow( logger ).to receive( :notify )

        tests_ran = ""

        expect do
          subject.test_name "A" do
            subject.test_name "B" do
              subject.test_name "C" do
                subject.test_name "D" do
                  tests_ran << "D"
                end
                tests_ran << "C"
              end
              tests_ran << "B"
            end
            subject.test_name "E" do
              subject.test_name "F" do
                tests_ran << "F"
              end
              raise "Fail this test!"
              tests_ran << "E"
            end
            subject.test_name "G" do
              tests_ran << "G"
            end
          end
        end.to raise_exception("Fail this test!")

        expect(tests_ran).to eql("DCBF")

        a, b, c, d, e, f, g = ("A".."G").each_with_index.map { |name, ix| "Test #{ix + 1}: #{name}" }
        structure = {
          [a, b, c, d] => 1,
          [a, b, c] => 3,
          [a, b] => 5,
          [a, e, f] => 1,
          [a, e] => "X",
          [a] => "X"
        }
        structure.each do |path, duration|
          node = path.inject(@timed_node) { |node, child| node[child] }
          expect(node).not_to be_nil
          expect(node.content).to eql(duration)
        end
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
      # We changed this lambda to use the simplest assert possible; using assert_equal
      # caused an error in minitest 5.9.0 trying to write to the file system.
      block = lambda { assert(false, 'this assertion should be caught') }
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

    it ':to - skips the test if there are no applicable hosts' do
      allow( subject ).to receive( :hosts ).and_return( [] )
      allow( subject ).to receive( :hosts= )
      expect( logger ).to receive( :warn )
      expect( subject ).to receive( :skip_test ).with( 'No suitable hosts found with {}' )
      subject.confine( :to, {} )
    end

    it ':except - skips the test if there are no applicable hosts' do
      allow( subject ).to receive( :hosts ).and_return( [] )
      allow( subject ).to receive( :hosts= )
      expect( logger ).to receive( :warn )
      expect( subject ).to receive( :skip_test ).with( 'No suitable hosts found without {}' )
      subject.confine( :except, {} )
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

end
