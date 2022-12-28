require 'spec_helper'

module Beaker
  module Subcommands
    describe SubcommandUtil do

      let(:cli) {
        double("cli")
      }

      let(:rake) {
        double("rake")
      }

      let(:file) {
        double("file")
      }

      let(:store) {
        double("store")
      }

      let(:host) {
        double("host")
      }

      let(:hypervisors) {
        double("hypervisors")
      }

      let(:hosts) {
        double("hosts")
      }

      let(:hypervisors_object) {
        double("hypervisors_object")
      }

      let(:hosts_object) {
        double("hosts_object")
      }

      let(:network_manager){
        double("network_manager")
      }

      let(:save_object){
        double("save_object")
      }

      let(:load_object){
        double("load_object")
      }

      let(:yaml_object){
        double("yaml_object")
      }

      describe 'execute_subcommand' do
        it "determines if we should execute the init subcommand" do
          expect(subject.execute_subcommand?("init")).to be == true
        end

        it "does not attempt to execute intialize as a subcommand" do
          expect(subject.execute_subcommand?("initialize")).to be == false
        end

        it "determines if we should execute the help subcommand" do
          expect(subject.execute_subcommand?("help")).to be == true
        end

        it "determines if we should execute the provision subcommand" do
          expect(subject.execute_subcommand?("provision")).to be == true
        end

        it "determines that a subcommand should not be executed" do
          expect(subject.execute_subcommand?("notasubcommand")).to be == false
        end
      end


      describe 'error_with' do
        it "the exit value should default to 1" do
          expect(STDOUT).to receive(:puts).with("exiting").once
          begin
            subject.error_with("exiting")
          rescue SystemExit=>e
            expect(e.status).to eq(1)
          end
        end

        it "the exit value should return specified value" do
          expect(STDOUT).to receive(:puts).with("exiting").once
          begin
            subject.error_with("exiting", {exit_code: 3})
          rescue SystemExit=>e
            expect(e.status).to eq(3)
          end
        end

        it "the exit value should default to 1 with a stack trace" do
          expect(STDOUT).to receive(:puts).with("exiting").once
          expect(STDOUT).to receive(:puts).with("testing").once
          begin
            subject.error_with("exiting", {stack_trace: "testing"})
          rescue SystemExit=>e
            expect(e.status).to eq(1)
          end
        end
      end

      describe 'prune_unpersisted' do
        let(:good_options) do
          { user: 'root', roles: ['agent'] }
        end

        let(:bad_options) do
          { logger: Beaker::Logger.new, timestamp: Time.now }
        end

        let(:initial_options) do
          Beaker::Options::OptionsHash.new.merge(good_options.merge(bad_options))
        end

        it 'removes unwanted keys from an options hash' do
          result = subject.prune_unpersisted(initial_options)
          good_options.keys.each { |key| expect(result).to have_key(key) }
          bad_options.keys.each { |key| expect(result).not_to have_key(key) }
        end

        it 'recurses to remove any nested unwanted keys' do
          opts = initial_options.merge(child: initial_options.merge(child: initial_options))
          result = subject.prune_unpersisted(opts)

          good_options.keys.each do |key|
            expect(result).to have_key(key)
            expect(result[:child]).to have_key(key)
            expect(result[:child][:child]).to have_key(key)
          end

          bad_options.keys.each do |key|
            expect(result).not_to have_key(key)
            expect(result[:child]).not_to have_key(key)
            expect(result[:child][:child]).not_to have_key(key)
          end
        end
      end
    end
  end
end
