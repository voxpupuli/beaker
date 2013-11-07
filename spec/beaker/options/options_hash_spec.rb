require "spec_helper"

module Beaker
  module Options
    describe OptionsHash do
      let(:options)    { Beaker::Options::OptionsHash.new }

      #test options hash methods
      it "converts all string keys to symbols when doing direct assignment" do
        options['key'] = 'value'
        expect(options.has_key?(:key)) === true  and expect(options.has_key?('key')) === false
      end

      it "can look up by string or symbol key" do
        options.merge({'key' => 'value'})
        expect(options['key']) === 'value' and expect(options[:key]) === 'value'
      end

      it "supports is_pe?, defaults to pe" do
        expect(options.is_pe?) === true
      end

      it "supports is_pe?, respects :type == foss" do
        options[:type] = 'foss'
        expect(options.is_pe?) === false
      end

      it "can delete by string of symbol key" do
        options['key'] = 'value'
        expect(options.delete('key')) === 'value' and expect(options.delete(:key)) === 'value'
      end

      it "when merged with a Hash remains an OptionsHash" do
        options.merge({'key' => 'value'})
        expect(options.is_a?(OptionsHash)) === true
      end

      it "when merged with a hash that contains a hash, the sub-hash becomes an OptionsHash" do
        options.merge({'key' => {'subkey' => 'subvalue'}})
        expect(options[:key].is_a?(OptionsHash)) === true and expect(options[:key][:subkey]) === 'subvalue'
      end

      it "supports a dump function" do
        expect{options.dump}.to_not raise_error
      end

      it "recursively dumps values" do
        options.merge({'k' => { 'key' => {'subkey' => 'subvalue'}}})
        expect(options.dump).to be === "Options:\n\t\tk : \n\t\t\tkey : \n\t\t\t\tsubkey : subvalue\n"
      end
    end
  end
end
