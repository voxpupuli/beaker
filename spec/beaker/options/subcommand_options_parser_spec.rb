require 'spec_helper'

module Beaker
  module Options
    describe '#parse_subcommand_options' do
      let(:home_options_file_path) {ENV['HOME']+'/.beaker/subcommand_options.yaml'}
      let( :parser ) {Beaker::Options::SubcommandOptionsParser.parse_subcommand_options(argv, home_dir)}
      let( :file_parser ){Beaker::Options::SubcommandOptionsParser.parse_options_file({})}
      let( :argv ) {[]}
      let( :home_dir ) {false}

      it 'returns an empty OptionsHash if not executing a subcommand' do
        expect(parser).to be_kind_of(OptionsHash)
        expect(parser).to be_empty
      end

      describe 'when the subcommand is init' do
        let( :argv ) {['init']}
        it 'returns an empty OptionsHash' do
          expect(parser).to be_kind_of(OptionsHash)
          expect(parser).to be_empty
        end
      end

      describe 'when the subcommand is not init' do
        let( :argv ) {['provision']}
        it 'calls parse_options_file with subcommand options file when home_dir is false' do
          allow(parser).to receive(:execute_subcommand?).with('provision').and_return true
          allow(parser).to receive(:parse_options_file).with(Beaker::Subcommands::SubcommandUtil::SUBCOMMAND_OPTIONS)
        end

        let ( :home_dir ) {true}
        it 'calls parse_options_file with home directory options file when home_dir is true' do
          allow(parser).to receive(:execute_subcommand?).with('provision').and_return true
          allow(parser).to receive(:parse_options_file).with(home_options_file_path)
        end

        let ( :home_dir ) {false}
        it 'checks for file existence and loads the YAML file' do
          allow(File).to receive(:exist?).and_return true
          allow(YAML).to receive(:load_file).and_return({})
          expect(file_parser).to be_kind_of(Hash)
          expect(file_parser).not_to be_kind_of(OptionsHash)
        end

      end
    end
  end
end
