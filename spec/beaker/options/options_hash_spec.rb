require "spec_helper"

module Beaker
  module Options
    describe OptionsHash do
      let(:options)    { described_class.new }


      it "supports is_pe?, defaults to pe" do
        expect(options).to be_is_pe
      end

      it "supports is_pe?, respects :type == foss" do
        options[:type] = 'foss'
        expect(options).not_to be_is_pe
      end

      describe '#get_type' do
        let(:options) { described_class.new }

        it 'returns pe as expected in the normal case' do
          newhash = options.merge({:type => 'pe'})
          expect(newhash.get_type).to be === :pe
        end

        it 'returns foss as expected in the normal case' do
          newhash = options.merge({:type => 'foss'})
          expect(newhash.get_type).to be === :foss
        end

        it 'returns foss as the default' do
          newhash = options.merge({:type => 'git'})
          expect(newhash.get_type).to be === :foss
        end
      end
    end

  end
end
