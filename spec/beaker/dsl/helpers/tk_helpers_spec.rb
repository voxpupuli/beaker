require 'spec_helper'

class ClassMixedWithDSLHelpers
  include Beaker::DSL::Helpers
  include Beaker::DSL::Wrappers
  include Beaker::DSL::Roles
  include Beaker::DSL::Patterns

  def logger
    RSpec::Mocks::Double.new('logger').as_null_object
  end

end

describe ClassMixedWithDSLHelpers do
  let( :opts )   { Beaker::Options::Presets.env_vars }
  let( :command ){ 'ls' }
  let( :host )   { double.as_null_object }
  let( :result ) { Beaker::Result.new( host, command ) }

  let( :master ) { make_host( 'master',   :roles => %w( master agent default)    ) }
  let( :agent )  { make_host( 'agent',    :roles => %w( agent )           ) }
  let( :custom ) { make_host( 'custom',   :roles => %w( custom agent )    ) }
  let( :dash )   { make_host( 'console',  :roles => %w( dashboard agent ) ) }
  let( :db )     { make_host( 'db',       :roles => %w( database agent )  ) }
  let( :hosts )  { [ master, agent, dash, db, custom ] }


  describe 'modify_tk_config' do
    let(:host) { double.as_null_object }
    let(:config_file_path) { 'existing-file-path'}
    let(:invalid_config_file_path) { 'nonexisting-file-path'}
    let(:options_hash) { {:key => 'value'} }
    let(:replace) { true }

    shared_examples 'modify-tk-config-without-error' do
      it 'dumps to the SUT config file path' do
        allow( JSON ).to receive(:dump)
        allow( subject ).to receive(:create_remote_file).with(host, config_file_path, anything())
        subject.modify_tk_config(host, config_file_path, options_hash, replace)
      end
    end

    before do
      allow( host ).to receive(:file_exist?).with(invalid_config_file_path).and_return(false)
      allow( host ).to receive(:file_exist?).with(config_file_path).and_return(true)
    end

    describe 'if file does not exist on SUT' do
      it 'raises Runtime error' do
        expect do
          subject.modify_tk_config(host, invalid_config_file_path, options_hash)
        end.to raise_error(RuntimeError, /.* does not exist on .*/)
      end
    end

    describe 'given an empty options hash' do
      it 'returns nil' do
        expect(subject.modify_tk_config(host, 'blahblah', {})).to eq(nil)
      end
    end

    describe 'given a non-empty options hash' do

      describe 'given a false value to its `replace` parameter' do
        let(:replace) { false }
        before do
          expect( subject ).to receive(:read_tk_config_string).with(anything())
        end
        include_examples('modify-tk-config-without-error')
      end

      describe 'given a true value to its `replace` parameter' do
        before do
          expect( JSON ).to receive(:dump)
          expect( subject ).to receive(:create_remote_file).with(host, config_file_path, anything())
        end
        include_examples('modify-tk-config-without-error')
      end
    end
  end

end
