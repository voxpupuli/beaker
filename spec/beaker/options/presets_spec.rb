require "spec_helper"

module Beaker
  module Options

    describe Presets do
      let(:presets)    { described_class.new }

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
        expect(env[:run_in_parallel]).to eq(['install', 'configure'])
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
