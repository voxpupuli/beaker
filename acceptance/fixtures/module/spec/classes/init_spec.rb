require 'spec_helper'
describe 'demo' do

  context 'with defaults for all parameters' do
    it { should contain_class('demo') }
  end
end
