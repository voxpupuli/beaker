require 'spec_helper'

class ClassMixedWithDSLHelpers
  include Beaker::DSL::Helpers
  include Beaker::DSL::Wrappers
  include Beaker::DSL::Roles
  include Beaker::DSL::Patterns

  def logger
    RSpec::Mocks::Double.new('logger').as_null_object
  end

end

describe ClassMixedWithDSLHelpers do
  let(:metadata) { @metadata ? @metadata : {} }

  describe '#current_test_name' do
    it 'returns nil if the case is undefined' do
      allow(subject).to receive(:metadata).and_return(metadata)
      expect( subject.current_test_name ).to be_nil
    end

    it 'returns nil if the name is undefined' do
      @metadata = { :case => {} }
      allow(subject).to receive(:metadata).and_return(metadata)
      expect( subject.current_test_name ).to be_nil
    end

    it 'returns the set value' do
      name = 'holyGrail_testName'
      @metadata = { :case => { :name => name } }
      allow(subject).to receive(:metadata).and_return(metadata)
      expect( subject.current_test_name ).to be === name
    end
  end

  describe '#current_test_filename' do
    it 'returns nil if the case is undefined' do
      allow(subject).to receive(:metadata).and_return(metadata)
      expect( subject.current_test_filename ).to be_nil
    end

    it 'returns nil if the name is undefined' do
      @metadata = { :case => {} }
      allow(subject).to receive(:metadata).and_return(metadata)
      expect( subject.current_test_filename ).to be_nil
    end

    it 'returns the set value' do
      name = 'holyGrail_testFilename'
      @metadata = { :case => { :file_name => name } }
      allow(subject).to receive(:metadata).and_return(metadata)
      expect( subject.current_test_filename ).to be === name
    end
  end

  describe '#current_step_name' do
    it 'returns nil if the step is undefined' do
      allow(subject).to receive(:metadata).and_return(metadata)
      expect( subject.current_step_name ).to be_nil
    end

    it 'returns nil if the name is undefined' do
      @metadata = { :step => {} }
      allow(subject).to receive(:metadata).and_return(metadata)
      expect( subject.current_step_name ).to be_nil
    end

    it 'returns the set value' do
      name = 'holyGrail_stepName'
      @metadata = { :step => { :name => name } }
      allow(subject).to receive(:metadata).and_return(metadata)
      expect( subject.current_step_name ).to be === name
    end
  end
end
