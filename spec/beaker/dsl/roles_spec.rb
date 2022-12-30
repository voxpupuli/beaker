require 'spec_helper'


class ClassMixedWithDSLRoles
  include Beaker::DSL::Roles
  include Beaker::DSL::Outcomes
end

describe ClassMixedWithDSLRoles do

  let( :hosts )      { @hosts || Hash.new }
  let( :options )    { @options || Hash.new }
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
      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject.agents ).to be == [ agent1, agent2, master ]
    end

    it 'and an empty array when none match' do
      @hosts = [ db, custom ]
      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject.agents ).to be == []
    end
  end

  describe '#master' do
    it 'returns the master if there is one' do
      @hosts = [ master, agent1 ]
      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject.master ).to be == master
    end

    it 'raises an error if there is more than one master' do
      @hosts = [ master, monolith ]
      expect( subject ).to receive( :hosts ).once.and_return( hosts )
      expect { subject.master }.to raise_error Beaker::DSL::FailTest
    end

    it 'returns nil if no master and masterless is set' do
      @options = { :masterless => true }
      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :options ).and_return( options )
      expect( subject.master ).to be_nil
    end
  end

  describe '#dashboard' do
    it 'returns the dashboard if there is one' do
      @hosts = [ a_and_dash, agent1 ]
      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject.dashboard ).to be == a_and_dash
    end

    it 'raises an error if there is more than one dashboard' do
      @hosts = [ a_and_dash, monolith ]
      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect { subject.dashboard }.to raise_error Beaker::DSL::FailTest
    end

    it 'and raises an error if there is no dashboard' do
      @hosts = [ agent1, agent2, custom ]
      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect { subject.dashboard }.to raise_error Beaker::DSL::FailTest
    end

    it 'returns nil if no dashboard and masterless is set' do
      @options = { :masterless => true }
      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :options ).and_return( options )
      expect( subject.dashboard ).to be_nil
    end
  end

  describe '#database' do
    it 'returns the database if there is one' do
      @hosts = [ db, agent1 ]
      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject.database ).to be == db
    end

    it 'raises an error if there is more than one database' do
      @hosts = [ db, monolith ]
      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect { subject.database }.to raise_error Beaker::DSL::FailTest
    end

    it 'and raises an error if there is no database' do
      @hosts = [ agent1, agent2, custom ]
      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect { subject.database }.to raise_error Beaker::DSL::FailTest
    end

    it 'returns nil if no database and masterless is set' do
      @options = { :masterless => true }
      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :options ).and_return( options )
      expect( subject.database ).to be_nil
    end
  end

  describe '#not_controller' do
    it 'returns true when a host does not have the roles master/database/dashboard' do
      expect( subject.not_controller(agent1) ).to be == true
    end

    it 'returns false when a host has one of the roles master/database/dashboard' do
      expect( subject.not_controller(a_and_dash) ).to be == false
    end
  end

  describe '#agent_only' do
    it 'returns true when a host has the single role agent' do
      expect( subject.agent_only(agent1) ).to be == true
    end

    it 'returns false when a host has more than a single role' do
      expect( subject.agent_only(a_and_dash) ).to be == false
    end

    it 'returns false when a host has the role master' do
      expect( subject.agent_only(master) ).to be == false
    end
  end

  describe '#aio_version?' do
    it 'returns false if the host doesn\'t have a :pe_ver or :version' do
      agent1[:pe_ver] = nil
      agent1[:version] = nil
      expect( subject.aio_version?(agent1) ).to be === false
    end

    it 'returns false if :version < 4.0 and pe_ver is nil, type foss' do
      agent1[:pe_ver] = nil
      agent1[:version] = '3.8'
      agent1[:type] = 'foss'
      expect( subject.aio_version?(agent1) ).to be === false
    end

    it 'returns false if the host :pe_ver is set < 4.0' do
      agent1[:pe_ver] = '3.8'
      expect( subject.aio_version?(agent1) ).to be === false
    end

    it 'returns false if the host :version is set < 4.0' do
      agent1[:version] = '3.8'
      expect( subject.aio_version?(agent1) ).to be === false
    end

    it 'returns true if the host :pe_ver is 4.0' do
      agent1[:pe_ver] = '4.0'
      expect( subject.aio_version?(agent1) ).to be === true
    end

    it 'returns true if the host :version is 4.0' do
      agent1[:version] = '4.0'
      expect( subject.aio_version?(agent1) ).to be === true
    end

    it 'returns true if the host :pe_ver is 2015.5' do
      agent1[:pe_ver] = '2015.5'
      expect( subject.aio_version?(agent1) ).to be === true
    end

    it 'returns true if the host has role aio' do
      agent1[:roles] = agent1[:roles] | ['aio']
      expect( subject.aio_version?(agent1) ).to be === true
    end

    it 'returns true if the host is type aio' do
      agent1[:type] = 'aio'
      expect( subject.aio_version?(agent1) ).to be === true
    end

    it 'returns true if the host is type aio-foss' do
      agent1[:type] = 'aio-foss'
      expect( subject.aio_version?(agent1) ).to be === true
    end

    it 'returns true if the host is type foss-aio' do
      agent1[:type] = 'aio-foss'
      expect( subject.aio_version?(agent1) ).to be === true
    end

    it 'can take an empty string for pe_ver' do
      agent1[:pe_ver] = ''
      expect{ subject.aio_version?(agent1) }.not_to raise_error
    end

    it 'can take an empty string for FOSS version' do
      agent1[:version] = ''
      expect{ subject.aio_version?(agent1) }.not_to raise_error
    end

    context 'truth table-type testing' do

      before do
        @old_pe_ver  = agent1[:pe_ver]
        @old_version = agent1[:version]
        @old_roles   = agent1[:roles]
        @old_type    = agent1[:type]
      end

      after do
        agent1[:pe_ver]   = @old_pe_ver
        agent1[:version]  = @old_version
        agent1[:roles]    = @old_roles
        agent1[:type]     = @old_type
      end

      context 'version values table' do
        # pe_ver, version, answer
        versions_table = [
          [nil,      nil, false],
          [nil,       '', false],
          [nil,    '3.9', false],
          [nil,    '4.0', true ],
          [nil, '2015.1', true ],
          \
          ['',      nil, false],
          ['',       '', false],
          ['',    '3.9', false],
          ['',    '4.0', true ],
          ['', '2015.1', true ],
          \
          ['3.9',      nil, false],
          ['3.9',       '', false],
          ['3.9',    '3.9', false],
          ['3.9',    '4.0', false],
          ['3.9', '2015.1', false],
          \
          ['4.0',      nil, true],
          ['4.0',       '', true],
          ['4.0',    '3.9', true],
          ['4.0',    '4.0', true],
          ['4.0', '2015.1', true],
          \
          ['2015.1',      nil, true],
          ['2015.1',       '', true],
          ['2015.1',    '3.9', true],
          ['2015.1',    '4.0', true],
          ['2015.1', '2015.1', true],
        ]

        versions_table.each do |answers_row|
          it "acts with values #{answers_row} correctly" do
            agent1[:pe_ver]   = answers_row[0]
            agent1[:version]  = answers_row[1]
            agent1[:roles]    = nil
            agent1[:type]     = nil
            expect( subject.aio_version?(agent1) ).to be === answers_row[2]
          end
        end
      end

      context 'roles values table' do
        roles_table = [
          [nil,           false],
          [[],            false],
          [['aio'],       true ],
          [['gun'],       false],
          [['a', 'b'],    false],
          [['c', 'aio'],  true ],
        ]

        roles_table.each do |answers_row|
          it "acts with values #{answers_row} correctly" do
            agent1[:pe_ver]   = nil
            agent1[:version]  = nil
            agent1[:roles]    = answers_row[0]
            agent1[:type]     = nil
            expect( subject.aio_version?(agent1) ).to be === answers_row[1]
          end
        end
      end

      context 'type values table' do
        type_table = [
          [nil,         false],
          ['',          false],
          ['cheese',    false],
          ['paionts',   false],
          ['aioch',     false],
          ['chaio',     false],
          ['aio',       true ],
          ['aio-',      true ],
          ['ew-aio-ji', true ],
          ['id-aiot',   false],
        ]

        type_table.each do |answers_row|
          it "acts with values #{answers_row} correctly" do
            agent1[:pe_ver]   = nil
            agent1[:version]  = nil
            agent1[:roles]    = nil
            agent1[:type]     = answers_row[0]
            expect( subject.aio_version?(agent1) ).to be === answers_row[1]
          end
        end
      end

    end

  end

  describe '#aio_agent?' do
    it 'returns false if agent_only check doesn\'t pass' do
      agent1[:roles] = ['agent', 'headless']
      expect( subject.aio_agent?(agent1) ).to be === false
    end

    it 'returns false if aio_capable? check doesn\'t pass' do
      agent1[:pe_ver] = '3.8'
      expect( subject.aio_agent?(agent1) ).to be === false
    end

    it 'returns true if both checks pass' do
      agent1[:pe_ver] = '4.0'
      expect( subject.aio_agent?(agent1) ).to be === true
    end
  end

  describe '#default' do
    it 'returns the default host when one is specified' do
      @hosts = [ db, agent1, agent2, default, master]
      expect( subject ).to receive( :hosts ).once.and_return( hosts )
      expect( subject.default ).to be == default
    end

    it 'raises an error if there is more than one default' do
      @hosts = [ db, monolith, default, default ]
      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect { subject.default }.to raise_error Beaker::DSL::FailTest
    end

    it 'and raises an error if there is no default' do
      @hosts = [ agent1, agent2, custom ]
      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect { subject.default }.to raise_error Beaker::DSL::FailTest
    end

    it 'returns nil if no default and masterless is set' do
      @options = { :masterless => true }
      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :options ).and_return( options )
      expect( subject.default ).to be_nil
    end
  end

  describe '#add_role_def' do
    it 'raises an error on unsupported role format "1role"' do
      expect { subject.add_role_def( "1role" ) }.to raise_error ArgumentError
    end

    it 'raises an error on unsupported role format "role_!a"' do
      expect { subject.add_role_def( "role_!a" ) }.to raise_error ArgumentError
    end

    it 'raises an error on unsupported role format "role=="' do
      expect { subject.add_role_def( "role==" ) }.to raise_error ArgumentError
    end

    it 'creates new method for role "role_correct!"' do
      test_role = "role_correct!"
      subject.add_role_def( test_role )
      expect( subject ).to respond_to test_role
      subject.class.send( :undef_method, test_role )
    end

    it 'returns a single node for a new method for a role defined in a single node' do
      @hosts = [ agent1, agent2, monolith ]
      expect( subject ).to receive( :hosts ).and_return( hosts )
      test_role = "custom_role"
      subject.add_role_def( test_role )
      expect( subject ).to respond_to test_role
      expect( subject.send( test_role )).to be == @hosts[2]
      subject.class.send( :undef_method, test_role )
    end

    it 'returns an array of nodes for a new method for a role defined in multiple nodes' do
      @hosts = [ agent1, agent2, monolith, custom ]
      expect( subject ).to receive( :hosts ).and_return( hosts )
      test_role = "custom_role"
      subject.add_role_def( test_role )
      expect( subject ).to respond_to test_role
      expect( subject.send( test_role )).to be == [@hosts[2], @hosts[3]]
      subject.class.send( :undef_method, test_role )
    end
  end

  describe '#any_hosts_as?' do
    it 'returns true if a host exists, false otherwise' do
      @hosts = [ agent1, agent2 ]
      # expect( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :hosts ).twice.and_return( hosts )
      expect( subject.any_hosts_as?( "agent" )).to be == true
      expect( subject.any_hosts_as?( "custom_role" )).to be == false
    end
  end
end
