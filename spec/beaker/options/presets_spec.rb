require "spec_helper"

module Beaker
  module Options

    describe Presets do
      let(:presets)    { Presets.new }

      it "returns an env_vars OptionsHash" do
        expect(presets.env_vars).to be_instance_of(Beaker::Options::OptionsHash)
      end

      it "removes all empty/nil entries in env_vars" do
        expect(presets.env_vars.has_value?(nil)).to be === false
        expect(presets.env_vars.has_value?({})).to be === false
      end

      it "returns a presets OptionsHash" do
        expect(presets.presets).to be_instance_of(Beaker::Options::OptionsHash)
      end

      describe 'when setting the type as pe from the environment' do
        describe 'sets type to pe if...' do
          it 'env var is set to "true"' do
            munged = presets.format_found_env_vars( {:is_pe => 'true'} )
            expect( munged[:type] ).to be == 'pe'
          end
          it 'env var is set to "yes"' do
            munged = presets.format_found_env_vars( {:is_pe => 'yes'} )
            expect( munged[:type] ).to be == 'pe'
          end
        end
        describe 'sets type to foss if...' do
          it 'env var is set to "false"' do
            munged = presets.format_found_env_vars( {:is_pe => 'true'} )
            expect( munged[:type] ).to be == 'pe'
          end
          it 'env var is set to "no"' do
            munged = presets.format_found_env_vars( {:is_pe => 'yes'} )
            expect( munged[:type] ).to be == 'pe'
          end
        end
        it 'does not set type otherwise' do
          munged = presets.format_found_env_vars( {:is_pe => nil} )
          expect( munged[:type] ).to be == nil
        end
      end
    end
  end
end
