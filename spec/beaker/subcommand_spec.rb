require 'spec_helper'

module Beaker
  SubcommandUtil = Beaker::Subcommands::SubcommandUtil
  describe Subcommand do
    let( :subcommand ) {
      Beaker::Subcommand.new
    }

    context '#initialize' do
      it 'creates a cli object' do
        expect(Beaker::CLI).to receive(:new).once
        subcommand
      end
      describe 'File operation initialization for subcommands' do
        it 'checks to ensure subcommand file resources exist' do
          expect(FileUtils).to receive(:mkdir_p).with(SubcommandUtil::CONFIG_DIR)
          expect(SubcommandUtil::SUBCOMMAND_OPTIONS).to receive(:exist?).and_return(true)
          expect(SubcommandUtil::SUBCOMMAND_STATE).to receive(:exist?).and_return(true)
          subcommand
        end

        it 'touches the files when they do not exist' do
          expect(FileUtils).to receive(:mkdir_p).with(SubcommandUtil::CONFIG_DIR)
          allow(SubcommandUtil::SUBCOMMAND_OPTIONS).to receive(:exist?).and_return(false)
          allow(SubcommandUtil::SUBCOMMAND_STATE).to receive(:exist?).and_return(false)
          expect(FileUtils).to receive(:touch).with(SubcommandUtil::SUBCOMMAND_OPTIONS)
          expect(FileUtils).to receive(:touch).with(SubcommandUtil::SUBCOMMAND_STATE)
          subcommand
        end

      end
    end

    context '#init' do
      let( :cli ) { subcommand.instance_variable_get(:@cli) }
      let( :mock_options ) { {:timestamp => 'noon', :other_key => 'cordite'}}
      let( :yaml_store_mock ) { double('yaml_store_mock') }
      it 'calculates options and writes them to disk and deletes the' do
        expect(cli).to receive(:parse_options)
        allow(cli).to receive(:configured_options).and_return(mock_options)

        allow(File).to receive(:open)
        allow(YAML::Store).to receive(:new).with(SubcommandUtil::SUBCOMMAND_STATE).and_return(yaml_store_mock)
        allow(yaml_store_mock).to receive(:transaction).and_yield
        expect(yaml_store_mock).to receive(:[]=).with('provisioned', false)
        subcommand.init
        expect(mock_options).not_to have_key(:timestamp)
      end
    end

    context '#provision' do
      let ( :cli ) { subcommand.instance_variable_get(:@cli) }
      let( :yaml_store_mock ) { double('yaml_store_mock') }
      let ( :host_hash ) { {'mynode.net' => {:name => 'mynode', :platform => Beaker::Platform.new('centos-6-x86_64')}}}
      it 'provisions the host and saves the host info' do
        expect(YAML::Store).to receive(:new).with(SubcommandUtil::SUBCOMMAND_STATE).and_return(yaml_store_mock)
        allow(yaml_store_mock).to receive(:[]).and_return(false)
        expect(cli).to receive(:parse_options)
        expect(cli).to receive(:provision)
        expect(cli).to receive(:combined_instance_and_options_hosts).and_return(host_hash)
        expect(SubcommandUtil).to receive(:sanitize_options_for_save).and_return('cleaned hosts')
        expect(YAML::Store).to receive(:new).with(SubcommandUtil::SUBCOMMAND_OPTIONS).and_return(yaml_store_mock)

        expect(yaml_store_mock).to receive(:transaction).and_yield.exactly(3).times
        expect(yaml_store_mock).to receive(:[]=).with('HOSTS', 'cleaned hosts')

        expect(yaml_store_mock).to receive(:[]=).with('provisioned', true)
        subcommand.provision
      end
    end
  end
end
