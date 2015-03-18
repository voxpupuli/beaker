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


  describe "#write_hiera_config_on" do
    let(:hierarchy) { [ 'nodes/%{::fqdn}', 'common' ] }
    it 'on FOSS host' do
      host = make_host('testhost', { :platform => 'ubuntu' } )
      expect(subject).to receive(:create_remote_file).with(host, host.puppet['hiera_config'], /#{host[:hieradatadir]}/)
      subject.write_hiera_config_on(host, hierarchy)
    end

    it 'on PE host' do
      host = make_host('testhost', { :platform => 'ubuntu', :type => 'pe' } )
      expect(subject).to receive(:create_remote_file).with(host, host.puppet['hiera_config'], /#{host[:hieradatadir]}/)
      subject.write_hiera_config_on(host, hierarchy)
    end

  end

  describe "#write_hiera_config" do
    let(:hierarchy) { [ 'nodes/%{::fqdn}', 'common' ] }
    it 'delegates to #write_hiera_config_on with the default host' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :write_hiera_config_on ).with( master, hierarchy).once
      subject.write_hiera_config( hierarchy )
    end

  end

  describe "#copy_hiera_data_to" do
    let(:path) { 'spec/fixtures/hieradata' }
    it 'on FOSS host' do
      host = make_host('testhost', { :platform => 'ubuntu' } )
      expect(subject).to receive(:scp_to).with(host, File.expand_path(path), host[:hieradatadir])
      subject.copy_hiera_data_to(host, path)
    end

    it 'on PE host' do
      host = make_host('testhost', { :platform => 'ubuntu', :type => 'pe' } )
      expect(subject).to receive(:scp_to).with(host, File.expand_path(path), host[:hieradatadir])
      subject.copy_hiera_data_to(host, path)
    end
  end

  describe "#copy_hiera_data" do
    let(:path) { 'spec/fixtures/hieradata' }
    it 'delegates to #copy_hiera_data_to with the default host' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :copy_hiera_data_to ).with( master, path).once
      subject.copy_hiera_data( path )
    end

  end

  describe '#hiera_datadir' do
    it 'returns the codedir based hieradatadir for AIO' do
      host = hosts[0]
      host['type'] = :aio
      correct_answer = File.join(host.puppet['codedir'], 'hieradata')
      expect( subject.hiera_datadir(host) ).to be === correct_answer
    end

    it 'returns the hieradata host value for anything not AIO (backwards compatible)' do
      host_hieradatadir_value = '/home/fishing/man/pants'
      host = hosts[0]
      host[:hieradatadir] = host_hieradatadir_value
      expect( subject.hiera_datadir(host) ).to be === host_hieradatadir_value
    end
  end

end
