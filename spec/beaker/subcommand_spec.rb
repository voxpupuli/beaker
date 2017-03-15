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
      let ( :cleaned_hosts ) {double()}
      let ( :yielded_host_hash ) {double()}
      let ( :yielded_host_name) {double()}
      it 'provisions the host and saves the host info' do
        expect(YAML::Store).to receive(:new).with(SubcommandUtil::SUBCOMMAND_STATE).and_return(yaml_store_mock)
        allow(yaml_store_mock).to receive(:[]).and_return(false)
        expect(cli).to receive(:parse_options)
        expect(cli).to receive(:provision)
        expect(cli).to receive(:combined_instance_and_options_hosts).and_return(host_hash)
        expect(SubcommandUtil).to receive(:sanitize_options_for_save).and_return(cleaned_hosts)
        expect(cleaned_hosts).to receive(:each).and_yield(yielded_host_name, yielded_host_hash)
        expect(yielded_host_hash).to receive(:[]=).with('provision', false)
        expect(YAML::Store).to receive(:new).with(SubcommandUtil::SUBCOMMAND_OPTIONS).and_return(yaml_store_mock)

        expect(yaml_store_mock).to receive(:transaction).and_yield.exactly(3).times
        expect(yaml_store_mock).to receive(:[]=).with('HOSTS', cleaned_hosts)

        expect(yaml_store_mock).to receive(:[]=).with('provisioned', true)
        subcommand.provision
      end
    end


    context 'exec' do
      it 'calls execute! when no resource is given' do
        expect_any_instance_of(Pathname).to_not receive(:directory?)
        expect_any_instance_of(Pathname).to_not receive(:exist?)
        expect_any_instance_of(Beaker::CLI).to receive(:parse_options).once
        expect_any_instance_of(Beaker::CLI).to receive(:initialize_network_manager).once
        expect_any_instance_of(Beaker::CLI).to receive(:execute!).once
        expect{subcommand.exec}.to_not raise_error
      end

      it 'checks to to see if the resource is a file_resource' do

        expect_any_instance_of(Pathname).to receive(:exist?).and_return(true)
        expect_any_instance_of(Pathname).to receive(:directory?).and_return(false)
        expect_any_instance_of(Pathname).to receive(:expand_path).once
        expect_any_instance_of(Beaker::CLI).to receive(:execute!).once
        expect{subcommand.exec('resource')}.to_not raise_error
      end

      it 'checks to see if the resource is a directory' do
        expect_any_instance_of(Pathname).to receive(:exist?).and_return(true)
        expect_any_instance_of(Pathname).to receive(:directory?).and_return(true)
        expect(Dir).to receive(:glob)
        expect_any_instance_of(Pathname).to receive(:expand_path).once
        expect_any_instance_of(Beaker::CLI).to receive(:execute!).once
        expect{subcommand.exec('resource')}.to_not raise_error
      end

      it 'allows a hard coded suite name to be specified' do

        allow_any_instance_of(Pathname).to receive(:exist?).and_return(false)
        expect_any_instance_of(Beaker::CLI).to receive(:execute!).once
        expect{subcommand.exec('tests')}.to_not raise_error
      end

      it 'errors when a resource is neither a valid file resource or suite name' do
        allow_any_instance_of(Pathname).to receive(:exist?).and_return(false)
        expect{subcommand.exec('blahblahblah')}.to raise_error(ArgumentError)
      end
    end
  end
end
