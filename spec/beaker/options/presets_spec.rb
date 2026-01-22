require "spec_helper"

module Beaker
  module Options
    describe Presets do
      let(:presets) { described_class.new }

      it "returns an env_vars OptionsHash" do
        expect(presets.env_vars).to be_instance_of(Beaker::Options::OptionsHash)
      end

      it "pulls in env vars of the form ':q_*' and adds them to the :answers of the OptionsHash" do
        ENV['q_puppet_cloud_install'] = 'n'
        env = presets.env_vars
        expect(env[:answers][:q_puppet_cloud_install]).to be === 'n'
        expect(env[:answers]['q_puppet_cloud_install']).to be === 'n'
        ENV.delete('q_puppet_cloud_install')
      end

      it "correctly parses the run_in_parallel array" do
        ENV['BEAKER_RUN_IN_PARALLEL'] = "install,configure"
        env = presets.env_vars
        expect(env[:run_in_parallel]).to eq(%w[install configure])
      end

      describe "color environment variables" do
        after do
          ENV.delete('NO_COLOR')
          ENV.delete('BEAKER_COLOR')
        end

        it "disables color when NO_COLOR is set to any non-empty value" do
          ENV['NO_COLOR'] = '1'
          env = presets.env_vars
          expect(env[:color]).to be false
        end

        it "does not set color when NO_COLOR is set to an empty string" do
          ENV['NO_COLOR'] = ''
          env = presets.env_vars
          expect(env).not_to have_key(:color)
        end

        it "disables color when BEAKER_COLOR is set to 'no'" do
          ENV['BEAKER_COLOR'] = 'no'
          env = presets.env_vars
          expect(env[:color]).to be false
        end

        it "disables color when BEAKER_COLOR is set to 'false'" do
          ENV['BEAKER_COLOR'] = 'false'
          env = presets.env_vars
          expect(env[:color]).to be false
        end

        it "enables color when BEAKER_COLOR is set to 'yes'" do
          ENV['BEAKER_COLOR'] = 'yes'
          env = presets.env_vars
          expect(env[:color]).to be true
        end

        it "enables color when BEAKER_COLOR is set to 'true'" do
          ENV['BEAKER_COLOR'] = 'true'
          env = presets.env_vars
          expect(env[:color]).to be true
        end

        it "prioritizes BEAKER_COLOR over NO_COLOR" do
          ENV['NO_COLOR'] = '1'
          ENV['BEAKER_COLOR'] = 'yes'
          env = presets.env_vars
          expect(env[:color]).to be true
        end
      end

      it "removes all empty/nil entries in env_vars" do
        expect(presets.env_vars.has_value?(nil)).to be === false
        expect(presets.env_vars.has_value?({})).to be === false
      end

      it "returns a presets OptionsHash" do
        expect(presets.presets).to be_instance_of(Beaker::Options::OptionsHash)
      end

      it 'has empty host_tags' do
        expect(presets.presets).to have_key(:host_tags)
        expect(presets.presets[:host_tags]).to eq({})
      end
    end
  end
end
