require "spec_helper"

module Beaker
  module Options

    describe Presets do
      let(:presets)    { Presets.new }

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

      it "removes all empty/nil entries in env_vars" do
        expect(presets.env_vars.has_value?(nil)).to be === false
        expect(presets.env_vars.has_value?({})).to be === false
      end

      it "returns a presets OptionsHash" do
        expect(presets.presets).to be_instance_of(Beaker::Options::OptionsHash)
      end

    end
  end
end
