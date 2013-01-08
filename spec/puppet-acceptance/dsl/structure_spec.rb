require 'spec_helper'

class ClassMixedWithDSLStructure
  include PuppetAcceptance::DSL::Structure
end

describe ClassMixedWithDSLStructure do
  let(:logger) { Object.new }
  describe '#step' do
    it 'requires a name' do
      expect { subject.step do; end }.to raise_error ArgumentError
    end

    it 'notifies the logger' do
      subject.should_receive( :logger ).and_return( logger )
      logger.should_receive( :notify )
      subject.step 'blah'
    end

    it 'yields if a block is given' do
      subject.should_receive( :logger ).and_return( logger )
      logger.should_receive( :notify )
      subject.should_receive( :foo )
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
      subject.should_receive( :logger ).and_return( logger )
      logger.should_receive( :notify )
      subject.test_name 'blah'
    end

    it 'yields if a block is given' do
      subject.should_receive( :logger ).and_return( logger )
      logger.should_receive( :notify )
      subject.should_receive( :foo )
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
      teardown_array.should_receive( :<< ).with( block )
      subject.teardown &block
    end
  end
end
