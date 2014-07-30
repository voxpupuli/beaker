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
  let( :custom )     { make_host( 'custom',     { :roles => [ 'custom_role' ] } ) }
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
  describe '#add_role_def' do
    it 'raises an error on unsupported role format "1role"' do
      expect { subject.add_role_def( "1role" ) }.to raise_error
    end
    it 'raises an error on unsupported role format "role_!a"' do
      expect { subject.add_role_def( "role_!a" ) }.to raise_error
    end
    it 'raises an error on unsupported role format "role=="' do
      expect { subject.add_role_def( "role==" ) }.to raise_error
    end
    it 'creates new method for role "role_correct!"' do
      test_role = "role_correct!"
      subject.add_role_def( test_role )
      subject.should respond_to test_role
      subject.class.send( :undef_method, test_role )
    end
    it 'returns a single node for a new method for a role defined in a single node' do
      @hosts = [ agent1, agent2, monolith ]
      subject.should_receive( :hosts ).and_return( hosts )
      test_role = "custom_role"
      subject.add_role_def( test_role )
      subject.should respond_to test_role
      expect( subject.send( test_role )).to be == @hosts[2]
      subject.class.send( :undef_method, test_role )
    end
    it 'returns an array of nodes for a new method for a role defined in multiple nodes' do
      @hosts = [ agent1, agent2, monolith, custom ]
      subject.should_receive( :hosts ).and_return( hosts )
      test_role = "custom_role"
      subject.add_role_def( test_role )
      subject.should respond_to test_role
      expect( subject.send( test_role )).to be == [@hosts[2], @hosts[3]]
      subject.class.send( :undef_method, test_role )
    end
  end
end
