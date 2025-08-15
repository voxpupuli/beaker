require 'spec_helper'
require 'readline'

class ClassMixedWithDSLStructure
  include Beaker::DSL::Structure
  include Beaker::DSL::Helpers::TestHelpers
end

describe ClassMixedWithDSLStructure do
  include Beaker::DSL::Assertions

  let(:logger) { double }
  let(:metadata) { @metadata ||= {} }

  before do
    allow(subject).to receive(:metadata).and_return(metadata)
  end

  describe '#step' do
    it 'requires a name' do
      expect { subject.step { ; } }.to raise_error ArgumentError
    end

    it 'notifies the logger' do
      allow(subject).to receive(:set_current_step_name)
      expect(subject).to receive(:logger).and_return(logger)
      expect(logger).to receive(:notify)
      subject.step 'blah'
    end

    it 'yields if a block is given' do
      expect(subject).to receive(:logger).and_return(logger).twice
      allow(subject).to receive(:set_current_step_name)
      allow(logger).to receive(:with_indent).and_yield
      expect(logger).to receive(:notify)
      expect(subject).to receive(:foo)
      subject.step 'blah' do
        subject.foo
      end
    end

    it 'sets the metadata' do
      allow(subject).to receive(:logger).and_return(logger)
      allow(logger).to receive(:notify)
      step_name = 'pierceBrosnanTests'
      subject.step step_name
      expect(metadata[:step][:name]).to be === step_name
    end
  end

  describe '#manual_step' do
    context 'without exec manual test option' do
      let(:options) { {} }

      it 'throws an error' do
        expect(Readline).not_to receive(:readline)
        expect { subject.manual_step 'blah' do; end }.to raise_error StandardError
      end
    end

    context 'with exec manual test option' do
      let(:options) { { exec_manual_tests: nil } }

      it 'requires a name' do
        expect { subject.manual_step { ; } }.to raise_error ArgumentError
      end

      it 'notifies the logger' do
        subject.instance_variable_set(:@options, options)
        allow(subject).to receive(:set_current_step_name)
        expect(subject).to receive(:logger).and_return(logger)
        expect(logger).to receive(:notify)
        allow(Readline).to receive(:readline).and_return('Y')
        subject.manual_step 'blah'
      end
    end

    context 'with exec manual test option set to true' do
      let(:options) { { exec_manual_tests: true } }

      it 'requires a name' do
        expect { subject.manual_step { ; } }.to raise_error ArgumentError
      end

      it 'pass when user enters Y' do
        subject.instance_variable_set(:@options, options)
        allow(subject).to receive(:set_current_step_name)
        allow(subject).to receive(:logger).and_return(logger)
        allow(logger).to receive(:notify)
        expect(Readline).to receive(:readline).and_return('Y')
        subject.manual_step 'blahblah'
      end

      it 'fails when user enters n and uses default error when no message is entered' do
        subject.instance_variable_set(:@options, options)
        allow(subject).to receive(:set_current_step_name)
        allow(subject).to receive(:logger).and_return(logger)
        allow(logger).to receive(:notify)
        expect(Readline).to receive(:readline).and_return('n', 'step failed')
        expect { subject.manual_step 'blah two' do; end }.to raise_error(Beaker::DSL::FailTest, 'step failed')
      end
    end
  end

  describe '#manual_test' do
    context 'without exec manual test option' do
      let(:options) { {} }

      it 'requires a name' do
        expect { subject.manual_test { ; } }.to raise_error ArgumentError
      end

      it 'raises a skip test' do
        subject.instance_variable_set(:@options, options)
        allow(subject).to receive(:logger).and_return(logger)
        allow(logger).to receive(:notify)
        test_name = 'random test name'
        expect { subject.manual_test test_name do; end }.to raise_error Beaker::DSL::SkipTest
      end
    end

    context 'with exec manual test option' do
      let(:options) { { exec_manual_tests: true } }

      it 'requires a name' do
        expect { subject.manual_test { ; } }.to raise_error ArgumentError
      end

      it 'notifies the logger' do
        subject.instance_variable_set(:@options, options)
        expect(subject).to receive(:logger).and_return(logger)
        expect(logger).to receive(:notify)
        subject.manual_test 'blah blah'
      end

      it 'yields if a block is given' do
        subject.instance_variable_set(:@options, options)
        expect(subject).to receive(:logger).and_return(logger).twice
        expect(logger).to receive(:notify)
        allow(logger).to receive(:with_indent).and_yield
        expect(subject).to receive(:foo)
        subject.manual_test 'blah' do
          subject.foo
        end
      end

      it 'sets the metadata' do
        subject.instance_variable_set(:@options, options)
        allow(subject).to receive(:logger).and_return(logger)
        allow(logger).to receive(:notify)
        test_name = 'test is setting metadata yay!'
        subject.manual_test test_name
        expect(metadata[:case][:name]).to be === test_name
      end
    end
  end

  describe '#test_name' do
    it 'requires a name' do
      expect { subject.test_name { ; } }.to raise_error ArgumentError
    end

    it 'notifies the logger' do
      expect(subject).to receive(:logger).and_return(logger)
      expect(logger).to receive(:notify)
      subject.test_name 'blah'
    end

    it 'yields if a block is given' do
      expect(subject).to receive(:logger).and_return(logger).twice
      expect(logger).to receive(:notify)
      allow(logger).to receive(:with_indent).and_yield
      expect(subject).to receive(:foo)
      subject.test_name 'blah' do
        subject.foo
      end
    end

    it 'sets the metadata' do
      allow(subject).to receive(:logger).and_return(logger)
      allow(logger).to receive(:notify)
      test_name = '15-05-08\'s weather is beautiful'
      subject.test_name test_name
      expect(metadata[:case][:name]).to be === test_name
    end
  end

  describe '#teardown' do
    it 'append a block to the @teardown var' do
      teardown_array = double
      subject.instance_variable_set :@teardown_procs, teardown_array
      block = -> { 'blah' }
      expect(teardown_array).to receive(:<<).with(block)
      subject.teardown(&block)
    end
  end

  describe '#expect_failure' do
    it 'passes when a Minitest assertion is raised' do
      expect(subject).to receive(:logger).and_return(logger)
      expect(logger).to receive(:notify)
      # We changed this lambda to use the simplest assert possible; using assert_equal
      # caused an error in Minitest 5.9.0 trying to write to the file system.
      block = -> { assert(false, 'this assertion should be caught') }
      expect { subject.expect_failure 'this is an expected failure', &block }.not_to raise_error
    end

    it 'passes when a Beaker assertion is raised' do
      expect(subject).to receive(:logger).and_return(logger)
      expect(logger).to receive(:notify)
      block = -> { refute_match('1', '1', '1 and 1 should not match') }
      expect { subject.expect_failure 'this is an expected failure', &block }.not_to raise_error
    end

    it 'fails when a non-Beaker, non-Minitest assertion is raised' do
      block = -> { raise 'not a Beaker or Minitest error' }
      expect { subject.expect_failure 'this has a non-Beaker, non-Minitest exception', &block }.to raise_error(RuntimeError, /not a Beaker or Minitest error/)
    end

    it 'fails when no assertion is raised' do
      block = -> { expect('1').to(eq('1'), '1 should equal 1') }
      expect { subject.expect_failure 'this has no failure', &block }.to raise_error(RuntimeError, /An assertion was expected to fail, but passed/)
    end
  end

  describe '#confine' do
    let(:logger) { double.as_null_object }

    before do
      allow(subject).to receive(:logger).and_return(logger)
    end

    it ':to - skips the test if there are no applicable hosts' do
      allow(subject).to receive(:hosts).and_return([])
      allow(subject).to receive(:hosts=)
      expect(logger).to receive(:warn)
      expect(subject).to receive(:skip_test).with('No suitable hosts found with {}')
      subject.confine(:to, {})
    end

    it ':except - skips the test if there are no applicable hosts' do
      allow(subject).to receive(:hosts).and_return([])
      allow(subject).to receive(:hosts=)
      expect(logger).to receive(:warn)
      expect(subject).to receive(:skip_test).with('No suitable hosts found without {}')
      subject.confine(:except, {})
    end

    it ':to - uses a provided host subset when no criteria is provided' do
      subset = %w[host1 host2]
      hosts = subset.dup << 'host3'
      allow(subject).to receive(:hosts).and_return(hosts).twice
      expect(subject).to receive(:hosts=).with(subset)
      subject.confine :to, {}, subset
    end

    it ':except - excludes provided host subset when no criteria is provided' do
      subset = %w[host1 host2]
      hosts = subset.dup << 'host3'
      allow(subject).to receive(:hosts).and_return(hosts).twice
      expect(subject).to receive(:hosts=).with(hosts - subset)
      subject.confine :except, {}, subset
    end

    it 'raises when given mode is not :to or :except' do
      hosts = %w[host1 host2]
      allow(subject).to receive(:hosts).and_return(hosts)
      allow(subject).to receive(:hosts=)

      expect do
        subject.confine(:regardless, { :thing => 'value' })
      end.to raise_error('Unknown option regardless')
    end

    it 'rejects hosts that do not meet simple hash criteria' do
      hosts = [{ 'thing' => 'foo' }, { 'thing' => 'bar' }]

      expect(subject).to receive(:hosts).and_return(hosts).twice
      expect(subject).to receive(:hosts=)
        .with([{ 'thing' => 'foo' }])

      subject.confine :to, :thing => 'foo'
    end

    it 'rejects hosts that match a list of criteria' do
      hosts = [{ 'thing' => 'foo' }, { 'thing' => 'bar' }, { 'thing' => 'baz' }]

      expect(subject).to receive(:hosts).and_return(hosts).twice
      expect(subject).to receive(:hosts=)
        .with([{ 'thing' => 'bar' }])

      subject.confine :except, :thing => %w[foo baz]
    end

    it 'rejects hosts when a passed block returns true' do
      host1 = { 'platform' => 'el-9-64' }
      host2 = { 'platform' => 'el-10-64' }
      host3 = { 'platform' => 'windows' }
      hosts = [host1, host2, host3]

      expect(subject).to receive(:hosts).and_return(hosts).twice
      expect(subject).to receive(:on)
        .with(host1, 'firewall-cmd --state')
        .and_return(double('Beaker::Result', stdout: 'running'))
      expect(subject).to receive(:on)
        .with(host2, 'firewall-cmd --state')
        .and_return(double('Beaker::Result', stdout: 'stopped'))

      expect(subject).to receive(:hosts=).with([host1])

      subject.confine :to, :platform => 'el' do |host|
        subject.on(host, 'firewall-cmd --state').stdout == 'running'
      end
    end

    it 'doesn\'t corrupt the global hosts hash when confining from a subset of hosts' do
      host1 = { 'platform' => 'solaris', :roles => ['master'] }
      host2 = { 'platform' => 'solaris', :roles => ['agent'] }
      host3 = { 'platform' => 'windows', :roles => ['agent'] }
      hosts = [host1, host2, host3]
      agents = [host2, host3]

      expect(subject).to receive(:hosts).and_return(hosts)
      expect(subject).to receive(:hosts=).with([host2, host1])
      confined_hosts = subject.confine :except, { :platform => 'windows' }, agents
      expect(confined_hosts).to be === [host2, host1]
    end

    it 'can apply multiple confines correctly' do
      host1 = { 'platform' => 'solaris', :roles => ['master'] }
      host2 = { 'platform' => 'solaris', :roles => ['agent'] }
      host3 = { 'platform' => 'windows', :roles => ['agent'] }
      host4 = { 'platform' => 'fedora', :roles => ['agent'] }
      host5 = { 'platform' => 'fedora', :roles => ['agent'] }
      hosts = [host1, host2, host3, host4, host5]
      agents = [host2, host3, host4, host5]

      expect(subject).to receive(:hosts).and_return(hosts).exactly(3).times
      expect(subject).to receive(:hosts=).with([host1, host2, host4, host5])
      hosts = subject.confine :except, { :platform => 'windows' }
      expect(hosts).to be === [host1, host2, host4, host5]
      expect(subject).to receive(:hosts=).with([host4, host5, host1])
      hosts = subject.confine :to, { :platform => 'fedora' }, agents
      expect(hosts).to be === [host4, host5, host1]
    end

    it 'can apply confine with multiple arguments' do
      host1 = { 'platform' => 'solaris', 'hypervisor' => 'vmpooler' }
      host2 = { 'platform' => 'windows', 'hypervisor' => 'vmpooler' }
      host3 = { 'platform' => 'fedora', 'hypervisor' => 'vmpooler' }
      host4 = { 'platform' => 'fedora', 'hypervisor' => 'docker' }
      hosts = [host1, host2, host3, host4]

      expect(subject).to receive(:hosts).and_return(hosts).twice
      expect(subject).to receive(:hosts=).with([host1, host2, host3])
      result = subject.confine :except, { :platform => 'fedora', :hypervisor => 'docker' }
      expect(result).to eq([host1, host2, host3])
    end
  end

  describe '#select_hosts' do
    let(:logger) { double.as_null_object }

    before do
      allow(subject).to receive(:logger).and_return(logger)
    end

    it 'returns an empty array if there are no applicable hosts' do
      hosts = [{ 'thing' => 'foo' }, { 'thing' => 'bar' }]

      expect(subject.select_hosts({ 'thing' => 'nope' }, hosts)).to eq []
    end

    it 'selects hosts that match a list of criteria' do
      hosts = [{ 'thing' => 'foo' }, { 'thing' => 'bar' }, { 'thing' => 'baz' }]

      expect(subject.select_hosts({ :thing => %w[foo baz] }, hosts)).to eq [{ 'thing' => 'foo' }, { 'thing' => 'baz' }]
    end

    it 'selects hosts when a passed block returns true' do
      host1 = { 'platform' => 'el-9-64' }
      host2 = { 'platform' => 'el-10-64' }
      host3 = { 'platform' => 'windows' }
      hosts = [host1, host2, host3]
      expect(subject).to receive(:hosts).and_return(hosts)

      expect(subject).to receive(:on).with(host1, 'firewall-cmd --state').once.and_return(double('Beaker::Result', stdout: 'running'))
      expect(subject).to receive(:on).with(host2, 'firewall-cmd --state').once.and_return(double('Beaker::Result', stdout: 'stopped'))

      selected_hosts = subject.select_hosts 'platform' => 'el' do |host|
        subject.on(host, 'firewall-cmd --state').stdout == 'running'
      end
      expect(selected_hosts).to eq [host1]
    end
  end
end
