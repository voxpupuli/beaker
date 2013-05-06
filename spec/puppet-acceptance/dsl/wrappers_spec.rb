require 'spec_helper'

class ClassMixedWithDSLWrappers
  include PuppetAcceptance::DSL::Wrappers
end

describe ClassMixedWithDSLWrappers do
  let(:opts)  { {'ENV' => default_opts} }
  let(:default_opts) { PuppetAcceptance::Command::DEFAULT_GIT_ENV }
  describe '#facter' do
    it 'should split out the options and pass "facter" as first arg to Command' do
      PuppetAcceptance::Command.should_receive( :new ).
        with('facter', [ '-p' ], opts)
      subject.facter( '-p' )
    end
  end

  describe '#hiera' do
    it 'should split out the options and pass "hiera" as first arg to Command' do
      PuppetAcceptance::Command.should_receive( :new ).
        with('hiera', [ '-p' ], opts)
      subject.hiera( '-p' )
    end
  end

  describe '#puppet' do
    it 'should split out the options and pass "puppet <blank>" to Command' do
      merged_opts = {}
      merged_opts['ENV'] = {:HOME => '/'}.merge( default_opts )
      merged_opts[:server] = 'master'
      PuppetAcceptance::Command.should_receive( :new ).
        with('puppet agent', [ '-tv' ], merged_opts)
      subject.puppet( 'agent', '-tv', :server => 'master', 'ENV' => {:HOME => '/'})
    end
  end

  describe '#host_command' do
    it 'delegates to HostCommand.new' do
      PuppetAcceptance::HostCommand.should_receive( :new ).with( 'blah' )
      subject.host_command( 'blah' )
    end
  end

  describe 'deprecated puppet wrappers' do
    %w( resource doc kick cert apply master agent filebucket ).each do |sub|
      it "#{sub} delegates the proper info to #puppet" do
        subject.should_receive( :puppet ).with( sub, 'blah' )
        subject.send( "puppet_#{sub}", 'blah')
      end
    end
  end
end
