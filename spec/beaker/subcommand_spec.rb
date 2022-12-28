require 'spec_helper'

module Beaker
  SubcommandUtil = Beaker::Subcommands::SubcommandUtil
  describe Subcommand do
    let( :subcommand ) {
      described_class.new
    }

    describe '#initialize' do
      it 'creates a cli object' do
        expect(subcommand.cli).to be_instance_of(Beaker::CLI)
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

    context 'ensure that beaker options can be passed through' do

      let(:beaker_options_list) { [
        'options-file',
        'helper',
        'load-path',
        'tests',
        'pre-suite',
        'post-suite',
        'pre-cleanup',
        'provision',
        'preserve-hosts',
        'preserve-state',
        'root-keys',
        'keyfile',
        'timeout',
        'install',
        'modules',
        'quiet',
        'color',
        'color-host-output',
        'log-level',
        'log-prefix',
        'dry-run',
        'fail-mode',
        'ntp',
        'repo-proxy',
        'add-el-extras',
        'package-proxy',
        'validate',
        'collect-perf-data',
        'parse-only',
        'tag',
        'exclude-tags',
        'xml-time-order',
        'debug-errors',
        'exec_manual_tests',
        'test-tag-exclude',
        'test-tag-and',
        'test-tag-or',
        'xml',
        'type',
        'debug',
      ] }

      let( :yaml_store_mock ) { double('yaml_store_mock') }

      it 'does not error with valid beaker options' do
        beaker_options_list.each do |option|
          allow_any_instance_of(Beaker::CLI).to receive(:parse_options)
          allow_any_instance_of(Beaker::CLI).to receive(:configured_options).and_return({})

          allow(YAML::Store).to receive(:new).with(SubcommandUtil::SUBCOMMAND_STATE).and_return(yaml_store_mock)
          allow(yaml_store_mock).to receive(:transaction).and_yield
          allow(yaml_store_mock).to receive(:[]=).with('provisioned', false)
          allow(File).to receive(:open)
          allow_any_instance_of(Beaker::Logger).to receive(:notify).twice
          expect(SubcommandUtil::SUBCOMMAND_OPTIONS).to receive(:exist?).and_return(true)
          expect(SubcommandUtil::SUBCOMMAND_STATE).to receive(:exist?).and_return(true)

          expect {described_class.start(['init', '--hosts', 'centos', "--#{option}"])}.not_to output(/ERROR/).to_stderr
        end
      end

      it "errors with a bad option here" do
        allow(YAML::Store).to receive(:new).with(SubcommandUtil::SUBCOMMAND_STATE).and_return(yaml_store_mock)
        allow(yaml_store_mock).to receive(:transaction).and_yield
        allow(yaml_store_mock).to receive(:[]=).with('provisioned', false)
        expect(File).not_to receive(:open)
        expect(SubcommandUtil::SUBCOMMAND_OPTIONS).to receive(:exist?).and_return(true)
        expect(SubcommandUtil::SUBCOMMAND_STATE).to receive(:exist?).and_return(true)
        expect {described_class.start(['init', '--hosts', 'centos', '--bad-option'])}.to output(/ERROR/).to_stderr
      end
    end

    describe '#init' do
      let( :cli ) { subcommand.cli }
      let( :mock_options ) { {:timestamp => 'noon', :other_key => 'cordite'}}
      let( :yaml_store_mock ) { double('yaml_store_mock') }

      before do
        allow(cli).to receive(:parse_options)
        allow(cli).to receive(:configured_options).and_return(mock_options)
      end

      it 'calculates options and writes them to disk and deletes the' do
        allow(File).to receive(:open)
        allow(YAML::Store).to receive(:new).with(SubcommandUtil::SUBCOMMAND_STATE).and_return(yaml_store_mock)
        allow(yaml_store_mock).to receive(:transaction).and_yield
        expect(yaml_store_mock).to receive(:[]=).with('provisioned', false)
        subcommand.init
        expect(mock_options).not_to have_key(:timestamp)
      end

      it 'requires hosts flag' do
        expect{subcommand.init}.to raise_error(NotImplementedError)
      end
    end

    describe '#provision' do
      let( :cli ) { subcommand.cli }
      let( :yaml_store_mock ) { double('yaml_store_mock') }
      let( :host_hash ) { {'mynode.net' => {:name => 'mynode', :platform => Beaker::Platform.new('centos-6-x86_64')}}}
      let( :cleaned_hosts ) {double()}
      let( :yielded_host_hash ) {double()}
      let( :yielded_host_name) {double()}
      let( :network_manager) {double('network_manager')}
      let( :hosts) {double('hosts')}
      let( :hypervisors) {double('hypervisors')}
      let(:options) {double('options')}

      it 'provisions the host and saves the host info' do
        expect(YAML::Store).to receive(:new).with(SubcommandUtil::SUBCOMMAND_STATE).and_return(yaml_store_mock)
        allow(yaml_store_mock).to receive(:[]).and_return(false)
        allow(cli).to receive(:preserve_hosts_file).and_return("/path/to/ho")
        allow(cli).to receive(:network_manager).and_return(network_manager)
        allow(cli).to receive(:options).and_return(options)
        allow(options).to receive(:[]).with(:hosts_preserved_yaml_file).and_return("/path/to/hosts")
        allow(network_manager).to receive(:hosts).and_return(hosts)
        allow(network_manager).to receive(:hypervisors).and_return(hypervisors)
        expect(cli).to receive(:parse_options).and_return(cli)
        expect(cli).to receive(:provision)
        expect(cli).to receive(:combined_instance_and_options_hosts).and_return(host_hash)
        expect(SubcommandUtil).to receive(:sanitize_options_for_save).and_return(cleaned_hosts)
        expect(cleaned_hosts).to receive(:each).and_yield(yielded_host_name, yielded_host_hash)
        expect(yielded_host_hash).to receive(:[]=).with('provision', false)
        expect(YAML::Store).to receive(:new).with(SubcommandUtil::SUBCOMMAND_OPTIONS).and_return(yaml_store_mock)

        expect(yaml_store_mock).to receive(:transaction).and_yield.exactly(3).times
        expect(yaml_store_mock).to receive(:[]=).with('HOSTS', cleaned_hosts)
        expect(yaml_store_mock).to receive(:[]=).with('hosts_preserved_yaml_file', "/path/to/hosts")

        expect(yaml_store_mock).to receive(:[]=).with('provisioned', true)
        subcommand.provision
      end

      it 'does not allow hosts to be passed' do
        subcommand.options = {:hosts => "myhost"}
        expect{subcommand.provision()}.to raise_error(NotImplementedError)
      end
    end

    context 'exec' do
      before do
        allow(subcommand.cli).to receive(:parse_options)
        allow(subcommand.cli).to receive(:initialize_network_manager)
        allow(subcommand.cli).to receive(:execute!)
      end

      let( :cleaned_hosts ) {double()}
      let( :host_hash ) { {'mynode.net' => {:name => 'mynode', :platform => Beaker::Platform.new('centos-6-x86_64')}}}
      let( :yaml_store_mock ) { double('yaml_store_mock') }

      it 'calls execute! when no resource is given' do
        expect_any_instance_of(Pathname).not_to receive(:directory?)
        expect_any_instance_of(Pathname).not_to receive(:exist?)
        expect(subcommand.cli).to receive(:execute!).once
        expect{subcommand.exec}.not_to raise_error
      end

      it 'allows hard coded suite names to be specified' do
        subcommand.cli.options[:pre_suite] = %w[step1.rb]
        subcommand.cli.options[:post_suite] = %w[step2.rb]
        subcommand.cli.options[:tests] = %w[tests/1.rb]

        subcommand.exec('pre-suite,tests')

        expect(subcommand.cli.options[:pre_suite]).to eq(%w[step1.rb])
        expect(subcommand.cli.options[:post_suite]).to eq([])
        expect(subcommand.cli.options[:tests]).to eq(%w[tests/1.rb])
      end

      it 'errors when a resource is neither a valid file resource or suite name' do
        allow_any_instance_of(Pathname).to receive(:exist?).and_return(false)
        expect{subcommand.exec('blahblahblah')}.to raise_error(ArgumentError)
      end

      it 'accepts a tests directory, clearing all other suites' do
        allow_any_instance_of(Pathname).to receive(:exist?).and_return(true)
        allow_any_instance_of(Pathname).to receive(:directory?).and_return(true)
        allow(Dir).to receive(:glob)
          .with('tests/**/*.rb')
          .and_return(%w[tests/a.rb tests/b/c.rb])

        subcommand.exec('tests')

        expect(subcommand.cli.options[:pre_suite]).to eq([])
        expect(subcommand.cli.options[:post_suite]).to eq([])
        expect(subcommand.cli.options[:pre_cleanup]).to eq([])
        expect(subcommand.cli.options[:tests]).to eq(%w[tests/a.rb tests/b/c.rb])
      end

      it 'accepts comma-separated list of tests, clearing all other suites' do
        allow_any_instance_of(Pathname).to receive(:exist?).and_return(true)
        allow_any_instance_of(Pathname).to receive(:file?).and_return(true)

        subcommand.exec('tests/1.rb,tests/2.rb')

        expect(subcommand.cli.options[:pre_suite]).to eq([])
        expect(subcommand.cli.options[:post_suite]).to eq([])
        expect(subcommand.cli.options[:pre_cleanup]).to eq([])
        expect(subcommand.cli.options[:tests]).to eq(%w[tests/1.rb tests/2.rb])
      end

      it 'accepts comma-separated list of directories, recursively scanning each' do
        allow_any_instance_of(Pathname).to receive(:exist?).and_return(true)
        allow_any_instance_of(Pathname).to receive(:directory?).and_return(true)
        allow(Dir).to receive(:glob).with('tests/a/**/*.rb').and_return(%w[tests/a/x.rb])
        allow(Dir).to receive(:glob).with('tests/b/**/*.rb').and_return(%w[tests/b/x/y.rb tests/b/x/z.rb])

        subcommand.exec('tests/a,tests/b')

        expect(subcommand.cli.options[:tests]).to eq(%w[tests/a/x.rb tests/b/x/y.rb tests/b/x/z.rb])
      end

      it 'rejects comma-separated file and suite name' do
        allow_any_instance_of(Pathname).to receive(:exist?).and_return(false)

        expect {
          subcommand.exec('pre-suite,tests/whoops')
        }.to raise_error(ArgumentError, %r{Unable to parse pre-suite,tests/whoops})
      end



      it 'updates the subcommand_options file with new host info if `preserve-state` is set' do
        allow(yaml_store_mock).to receive(:[]).and_return(false)
        allow(subcommand).to receive(:options).and_return('preserve-state' => true)

        expect(subcommand.cli).to receive(:parse_options).and_return(subcommand.cli)
        expect(subcommand.cli).to receive(:combined_instance_and_options_hosts).and_return(host_hash)
        expect(SubcommandUtil).to receive(:sanitize_options_for_save).and_return(cleaned_hosts)
        expect(YAML::Store).to receive(:new).with(SubcommandUtil::SUBCOMMAND_OPTIONS).and_return(yaml_store_mock)
        expect(yaml_store_mock).to receive(:transaction).and_yield.once
        expect(yaml_store_mock).to receive(:[]=).with('HOSTS', cleaned_hosts)
        expect(subcommand.cli.logger).to receive(:notify)

        subcommand.exec('tests')
      end

      it 'does not attempt preserve state if the flag is not passed in' do
        subcommand.exec('tests')

        expect(SubcommandUtil).not_to receive(:sanitize_options_for_save)
        expect(subcommand.cli.options['preserve-state']).to be_nil
      end
    end

    context 'destroy' do
      let( :cli ) { subcommand.cli }
      let( :mock_options ) { {:timestamp => 'noon', :other_key => 'cordite'}}
      let( :yaml_store_mock ) { double('yaml_store_mock') }
      let( :network_manager) {double('network_manager')}

      it 'calls destroy and updates the yaml store' do
        allow(cli).to receive(:parse_options)
        allow(cli).to receive(:initialize_network_manager)
        allow(cli).to receive(:network_manager).and_return(network_manager)
        expect(network_manager).to receive(:cleanup)

        expect(YAML::Store).to receive(:new).with(SubcommandUtil::SUBCOMMAND_STATE).and_return(yaml_store_mock)
        allow(yaml_store_mock).to receive(:transaction).and_yield
        allow(yaml_store_mock).to receive(:[]).with('provisioned').and_return(true)
        allow(yaml_store_mock).to receive(:delete).with('provisioned').and_return(true)
        expect(SubcommandUtil).to receive(:error_with).with("Please provision an environment").exactly(0).times
        subcommand.destroy
      end
    end
  end
end
