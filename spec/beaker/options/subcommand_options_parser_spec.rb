require 'spec_helper'

module Beaker
  module Options
    describe '#parse_subcommand_options' do
      let( :parser ) {Beaker::Options::SubcommandOptionsParser.parse_subcommand_options(argv)}
      let( :argv ) {[]}

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
        it 'checks for file existence and loads the YAML file' do
          expect(Beaker::Subcommands::SubcommandUtil::SUBCOMMAND_OPTIONS).to receive(:exist?).and_return(true)
          allow(YAML).to receive(:load_file).and_return({})
          expect(parser).to be_kind_of(Hash)
          expect(parser).not_to be_kind_of(OptionsHash)
        end
      end
    end
  end
end
