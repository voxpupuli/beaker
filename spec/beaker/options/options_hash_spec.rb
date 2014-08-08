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
        expect(options.is_pe?).to be_true
      end

      it "supports is_pe?, respects :type == foss" do
        options[:type] = 'foss'
        expect(options.is_pe?).to be_false
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
        newhash = options.merge({'key' => {'subkey' => 'subvalue'}})
        expect(newhash[:key].is_a?(OptionsHash)) === true and expect(newhash[:key][:subkey]) === 'subvalue'
      end

      it "does not alter the original hash when doing a merge" do
        options.merge({'key' => {'subkey' => 'subvalue'}})
        expect(options[:key]).to be === nil
      end

      context 'pretty prints itself' do

        it 'in valid JSON' do
          require 'json'

          options['array'] = ['one', 'two', 'three']
          options['hash'] = {'subkey' => { 'subsub' => 1 }}
          options['nil'] = nil
          options['number'] = 4
          options['float'] = 1.0
          options['string'] = 'string'
          options['true'] = true

          expect{ JSON.parse( options.dump ) }.to_not raise_error
        end

        context 'for non collection values shows' do
          it 'non-string like values as bare words' do
            expect( options.fmt_value( 4 ) ).to be == "4"
            expect( options.fmt_value( 1.0 ) ).to be == "1.0"
            expect( options.fmt_value( true ) ).to be == "true"
            expect( options.fmt_value( false ) ).to be == "false"
          end

          it 'nil values as null' do
            expect( options.fmt_value( nil ) ).to be == 'null'
          end

          it 'strings within double quotes' do
            expect( options.fmt_value( 'thing' ) ).to be == '"thing"'
          end
        end

        context 'for list like collections shows' do
          it 'each element on a new line' do
            fmt_list = options.fmt_value( %w{ one two three } )

            expect( fmt_list ).to match(/^\s*"one",?$/)
            expect( fmt_list ).to match(/^\s*"two",?$/)
            expect( fmt_list ).to match(/^\s*"three",?$/)
          end

          it 'square brackets on either end of the list' do
            fmt_list = options.fmt_value( %w{ one two three } )

            expect( fmt_list ).to match( /\A\[\s*$/ )
            expect( fmt_list ).to match( /^\s*\]\Z/ )
          end
        end

        context 'for dict like collections shows' do
          it 'each element on a new line' do
            fmt_assoc = options.fmt_value( {:one => 'two', :two => 'three'} )

            expect( fmt_assoc ).to match(/^\s*"one": "two",?$/)
            expect( fmt_assoc ).to match(/^\s*"two": "three",?$/)
          end

          it 'curly braces on either end of the list' do
            fmt_assoc = options.fmt_value( {:one => 'two', :two => 'three'} )

            expect( fmt_assoc ).to match( /\A\{\s*$/ )
            expect( fmt_assoc ).to match( /^\s*\}\Z/ )
          end
        end
      end
    end
  end
end
