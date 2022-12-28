require 'spec_helper'
describe 'demo' do

  context 'with defaults for all parameters' do
    it { is_expected.to contain_class('demo') }
  end
end
