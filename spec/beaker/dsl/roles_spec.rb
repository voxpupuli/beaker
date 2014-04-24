require 'spec_helper'


class ClassMixedWithDSLRoles
  include Beaker::DSL::Roles
  include Beaker::DSL::Outcomes
end

describe ClassMixedWithDSLRoles do

  let( :hosts )      { @hosts || Hash.new }
  let( :agent1 )     { make_host( 'agent1',     { :roles => [ 'agent' ] } ) }
  let( :agent2 )     { make_host( 'agent2',     { :roles => [ 'agent' ] } ) }
  let( :a_and_dash ) { make_host( 'a_and_dash', { :roles => [ 'agent', 'dashboard' ] } ) }
  let( :custom )     { make_host( 'custom',     { :roles => [ 'custome_role' ] } ) }
  let( :db )         { make_host( 'db',         { :roles => [ 'database' ] } ) }
  let( :master )     { make_host( 'master',     { :roles => [ 'master', 'agent' ] } ) }
  let( :default )    { make_host( 'default',    { :roles => [ 'default'] } ) }
  let( :monolith )   { make_host( 'monolith',   { :roles => [ 'agent', 'dashboard', 'database', 'master', 'custom_role'] } ) }

  describe '#agents' do
    it 'returns an array of hosts that are agents' do
      @hosts = [ agent1, agent2, master ]
      subject.should_receive( :hosts ).and_return( hosts )
      expect( subject.agents ).to be == [ agent1, agent2, master ]
    end

    it 'and an empty array when none match' do
      @hosts = [ db, custom ]
      subject.should_receive( :hosts ).and_return( hosts )
      expect( subject.agents ).to be == []
    end
  end
  describe '#master' do
    it 'returns the master if there is one' do
      @hosts = [ master, agent1 ]
      subject.should_receive( :hosts ).and_return( hosts )
      expect( subject.master ).to be == master
    end
    it 'raises an error if there is more than one master' do
      @hosts = [ master, monolith ]
      subject.should_receive( :hosts ).exactly( 1 ).times.and_return( hosts )
      expect { subject.master }.to raise_error Beaker::DSL::FailTest
    end
  end
  describe '#dashboard' do
    it 'returns the dashboard if there is one' do
      @hosts = [ a_and_dash, agent1 ]
      subject.should_receive( :hosts ).and_return( hosts )
      expect( subject.dashboard ).to be == a_and_dash
    end
    it 'raises an error if there is more than one dashboard' do
      @hosts = [ a_and_dash, monolith ]
      subject.should_receive( :hosts ).and_return( hosts )
      expect { subject.dashboard }.to raise_error Beaker::DSL::FailTest
    end
    it 'and raises an error if there is no dashboard' do
      @hosts = [ agent1, agent2, custom ]
      subject.should_receive( :hosts ).and_return( hosts )
      expect { subject.dashboard }.to raise_error Beaker::DSL::FailTest
    end
  end
  describe '#database' do
    it 'returns the database if there is one' do
      @hosts = [ db, agent1 ]
      subject.should_receive( :hosts ).and_return( hosts )
      expect( subject.database ).to be == db
    end
    it 'raises an error if there is more than one database' do
      @hosts = [ db, monolith ]
      subject.should_receive( :hosts ).and_return( hosts )
      expect { subject.database }.to raise_error Beaker::DSL::FailTest
    end
    it 'and raises an error if there is no database' do
      @hosts = [ agent1, agent2, custom ]
      subject.should_receive( :hosts ).and_return( hosts )
      expect { subject.database }.to raise_error Beaker::DSL::FailTest
    end
  end
  describe '#default' do
    it 'returns the default host when one is specified' do
      @hosts = [ db, agent1, agent2, default, master]
      subject.should_receive( :hosts ).exactly( 1  ).times.and_return( hosts )
      expect( subject.default ).to be == default
    end
    it 'raises an error if there is more than one default' do
      @hosts = [ db, monolith, default, default ]
      subject.should_receive( :hosts ).and_return( hosts )
      expect { subject.database }.to raise_error Beaker::DSL::FailTest
    end
    it 'and raises an error if there is no default' do
      @hosts = [ agent1, agent2, custom ]
      subject.should_receive( :hosts ).and_return( hosts )
      expect { subject.database }.to raise_error Beaker::DSL::FailTest
    end
  end
end
