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

  describe '#on' do

    before :each do
      result.stdout = 'stdout'
      result.stderr = 'stderr'
      result.exit_code = 0
    end

    it 'allows the environment the command is run within to be specified' do
      allow( subject ).to receive( :hosts ).and_return( hosts )

      expect( Beaker::Command ).to receive( :new ).
        with( 'ls ~/.bin', [], {'ENV' => { :HOME => '/tmp/test_home' }} )

      subject.on( host, 'ls ~/.bin', :environment => {:HOME => '/tmp/test_home' } )
    end

    it 'if the host is a String Object, finds the matching hosts with that String as role' do
      allow( subject ).to receive( :hosts ).and_return( hosts )

      expect( master ).to receive( :exec ).once

      subject.on( 'master', 'echo hello')

    end

    it 'if the host is a Symbol Object, finds the matching hsots with that Symbol as role' do
      allow( subject ).to receive( :hosts ).and_return( hosts )

      expect( master ).to receive( :exec ).once

      subject.on( :master, 'echo hello')

    end

    it 'delegates to itself for each host passed' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expected = []
      hosts.each_with_index do |host, i|
        expected << i
        expect( host ).to receive( :exec ).and_return( i )
      end

      results = subject.on( hosts, command )
      expect( results ).to be == expected
    end

    context 'upon command completion' do
      before :each do
        allow( subject ).to receive( :hosts ).and_return( hosts )
        expect( host ).to receive( :exec ).and_return( result )
        @res = subject.on( host, command )
      end

      it 'returns the result of the action' do
        expect( @res ).to be == result
      end

      it 'provides access to stdout' do
        expect( @res.stdout ).to be == 'stdout'
      end

      it 'provides access to stderr' do
        expect( @res.stderr ).to be == 'stderr'
      end

      it 'provides access to exit_code' do
        expect( @res.exit_code ).to be == 0
      end
    end

    context 'when passed a block with arity of 1' do
      before :each do
        allow( subject ).to receive( :hosts ).and_return( hosts )
        expect( host ).to receive( :exec ).and_return( result )
      end

      it 'yields result' do
        subject.on host, command do |containing_class|
          expect( containing_class ).
            to be_an_instance_of( Beaker::Result )
        end
      end

      it 'provides access to stdout' do
        subject.on host, command do |containing_class|
          expect( containing_class.stdout ).to be == 'stdout'
        end
      end

      it 'provides access to stderr' do
        subject.on host, command do |containing_class|
          expect( containing_class.stderr ).to be == 'stderr'
        end
      end

      it 'provides access to exit_code' do
        subject.on host, command do |containing_class|
          expect( containing_class.exit_code ).to be == 0
        end
      end
    end

    context 'when passed a block with arity of 0' do
      before :each do
        allow( subject ).to receive( :hosts ).and_return( hosts )
        expect( host ).to receive( :exec ).and_return( result )
      end

      it 'yields self' do
        subject.on host, command do
          expect( subject ).
            to be_an_instance_of( ClassMixedWithDSLHelpers )
        end
      end

      it 'provides access to stdout' do
        subject.on host, command do
          expect( subject.stdout ).to be == 'stdout'
        end
      end

      it 'provides access to stderr' do
        subject.on host, command do
          expect( subject.stderr ).to be == 'stderr'
        end
      end

      it 'provides access to exit_code' do
        subject.on host, command do
          expect( subject.exit_code ).to be == 0
        end
      end
    end

  end

  describe "#retry_on" do
    it 'fails correctly when command never succeeds' do
      result.stdout = 'stdout'
      result.stderr = 'stderr'
      result.exit_code = 1

      retries = 5

      opts = {
        :max_retries    => retries,
        :retry_interval => 0.0001,
      }

      allow( subject ).to receive(:on).and_return(result)
      expect( subject ).to receive(:on).exactly(retries+2)
      expect { subject.retry_on(host, command, opts) }.to raise_error(RuntimeError)
    end

    it 'will return success correctly if it succeeds the first time' do
      result.stdout = 'stdout'
      result.stderr = 'stderr'
      result.exit_code = 0

      opts = {
        :max_retries    => 5,
        :retry_interval => 0.0001,
      }

      allow( subject ).to receive(:on).and_return(result)
      expect( subject ).to receive(:on).once

      result_given = subject.retry_on(host, command, opts)
      expect(result_given.exit_code).to be === 0
    end

    it 'will return success correctly if it succeeds after failing a few times' do
      result.stdout = 'stdout'
      result.stderr = 'stderr'

      opts = {
        :max_retries    => 10,
        :retry_interval => 0.1,
      }

      reps_num = 4
      count = 0
      allow( subject ).to receive(:on) do
        result.exit_code = count > reps_num ? 0 : 1
        count += 1
        result
      end
      expect( subject ).to receive(:on).exactly(reps_num + 2)

      result_given = subject.retry_on(host, command, opts)
      expect(result_given.exit_code).to be === 0
    end
  end

  describe "shell" do
    it 'delegates to #on with the default host' do
      allow( subject ).to receive( :hosts ).and_return( hosts )

      expect( subject ).to receive( :on ).with( master, "echo hello", {}).once

      subject.shell( "echo hello" )
    end
  end

  describe '#scp_from' do
    it 'delegates to the host' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :logger ).exactly( hosts.length ).times
      expect( result ).to receive( :log ).exactly( hosts.length ).times

      hosts.each do |host|
        expect( host ).to receive( :do_scp_from ).and_return( result )
      end

      subject.scp_from( hosts, '/var/log/my.log', 'log/my.log' )
    end
  end

  describe '#scp_to' do
    it 'delegates to the host' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :logger ).exactly( hosts.length ).times
      expect( result ).to receive( :log ).exactly( hosts.length ).times

      hosts.each do |host|
        expect( host ).to receive( :do_scp_to ).and_return( result )
      end

      subject.scp_to( hosts, '/var/log/my.log', 'log/my.log' )
    end
  end

  describe '#create_remote_file' do
    it 'scps the contents passed in to the hosts' do
      my_opts = { :silent => true }
      tmpfile = double

      expect( tmpfile ).to receive( :path ).exactly( 2 ).times.
        and_return( '/local/path/to/blah' )

      expect( Tempfile ).to receive( :open ).and_yield( tmpfile )

      expect( File ).to receive( :open )

      expect( subject ).to receive( :scp_to ).
        with( hosts, '/local/path/to/blah', '/remote/path', my_opts )

      subject.create_remote_file( hosts, '/remote/path', 'blah', my_opts )
    end
  end

  describe '#create_tmpdir_for_user' do
    let(:host) { {} }
    let(:result) { double.as_null_object }

    before :each do
      allow(host).to receive(:result).and_return(result)
      allow(result).to receive(:exit_code).and_return(0)
      allow(result).to receive(:stdout).and_return('puppet')
    end

    context 'with no user argument' do

      context 'with no path name argument' do
        context 'without puppet installed on host' do
          it 'raises an error' do
            cmd = "the command"
            allow(result).to receive(:exit_code).and_return(1)
            expect(Beaker::Command).to receive(:new).with(/puppet master --configprint user/, [], {"ENV"=>{}, :cmdexe=>true}).and_return(cmd)
            expect(subject).to receive(:on).with(host, cmd).and_return(result)
            expect{
              subject.create_tmpdir_for_user host
            }.to raise_error(RuntimeError, /`puppet master --configprint` failed,/)
          end
        end
        context 'with puppet installed on host' do
          it 'executes chown once' do
            cmd = "the command"
            expect(Beaker::Command).to receive(:new).with(/puppet master --configprint user/, [], {"ENV"=>{}, :cmdexe=>true}).and_return(cmd)
            expect(subject).to receive(:on).with(host, cmd).and_return(result)
            expect(subject).to receive(:on).with(host, /^getent passwd puppet/).and_return(result)
            expect(host).to receive(:tmpdir).with(/\/tmp\/beaker.*/)
            expect(subject).to receive(:on).with(host, /chown puppet.puppet.*/)
            subject.create_tmpdir_for_user(host)
          end
        end
      end

      context 'with path name argument' do
        it 'executes chown once' do
          cmd = "the command"
          expect(Beaker::Command).to receive(:new).with(/puppet master --configprint user/, [], {"ENV"=>{}, :cmdexe=>true}).and_return(cmd)
          expect(subject).to receive(:on).with(host, cmd).and_return(result)
          expect(subject).to receive(:on).with(host, /^getent passwd puppet/).and_return(result)
          expect(host).to receive(:tmpdir).with(/\/tmp\/bogus.*/).and_return("/tmp/bogus")
          expect(subject).to receive(:on).with(host, /chown puppet.puppet \/tmp\/bogus.*/)
          subject.create_tmpdir_for_user(host, "/tmp/bogus")
        end
      end

    end

    context 'with an invalid user argument' do
      it 'executes chown once' do
        allow(result).to receive(:stdout).and_return('curiousgeorge')
        expect(subject).to receive(:on).with(host, /^getent passwd curiousgeorge/).and_return(result)
        expect(host).to receive(:tmpdir).with(/\/tmp\/bogus.*/).and_return("/tmp/bogus")
        expect(subject).to receive(:on).with(host, /chown curiousgeorge.curiousgeorge \/tmp\/bogus.*/)
        subject.create_tmpdir_for_user(host, "/tmp/bogus", "curiousgeorge")
      end
    end

    context 'with a valid user argument' do
      it 'executes chown once' do
        allow(result).to receive(:exit_code).and_return(1)
        expect(subject).to receive(:on).with(host, /^getent passwd curiousgeorge/).and_return(result)
        expect{
          subject.create_tmpdir_for_user(host, "/tmp/bogus", "curiousgeorge")
        }.to raise_error(RuntimeError, /User curiousgeorge does not exist on/)
      end
    end

  end

  describe '#run_script_on' do
    it 'scps the script to a tmpdir and executes it on host(s)' do
      expect( subject ).to receive( :scp_to )
      expect( subject ).to receive( :on )
      subject.run_script_on( 'host', '~/.bin/make-enterprisy' )
    end
  end

  describe '#run_script' do
    it 'delegates to #run_script_on with the default host' do
      allow( subject ).to receive( :hosts ).and_return( hosts )

      expect( subject ).to receive( :run_script_on ).with( master, "/tmp/test.sh", {}).once

      subject.run_script( '/tmp/test.sh' )
    end
  end

  describe 'confine' do
    let(:logger) { double.as_null_object }
    before do
      allow( subject ).to receive( :logger ).and_return( logger )
    end

    it 'skips the test if there are no applicable hosts' do
      allow( subject ).to receive( :hosts ).and_return( [] )
      allow( subject ).to receive( :hosts= )
      expect( logger ).to receive( :warn )
      expect( subject ).to receive( :skip_test ).
        with( 'No suitable hosts found' )

      subject.confine( :to, {} )
    end

    it 'raises when given mode is not :to or :except' do
      allow( subject ).to receive( :hosts )
      allow( subject ).to receive( :hosts= )

      expect {
        subject.confine( :regardless, {:thing => 'value'} )
      }.to raise_error( 'Unknown option regardless' )
    end

    it 'rejects hosts that do not meet simple hash criteria' do
      hosts = [ {'thing' => 'foo'}, {'thing' => 'bar'} ]

      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :hosts= ).
        with( [ {'thing' => 'foo'} ] )

      subject.confine :to, :thing => 'foo'
    end

    it 'rejects hosts that match a list of criteria' do
      hosts = [ {'thing' => 'foo'}, {'thing' => 'bar'}, {'thing' => 'baz'} ]

      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :hosts= ).
        with( [ {'thing' => 'bar'} ] )

      subject.confine :except, :thing => ['foo', 'baz']
    end

    it 'rejects hosts when a passed block returns true' do
      host1 = {'platform' => 'solaris'}
      host2 = {'platform' => 'solaris'}
      host3 = {'platform' => 'windows'}
      ret1 = (Struct.new('Result1', :stdout)).new(':global')
      ret2 = (Struct.new('Result2', :stdout)).new('a_zone')
      hosts = [ host1, host2, host3 ]

      expect( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :on ).
        with( host1, '/sbin/zonename' ).
        and_return( ret1 )
      expect( subject ).to receive( :on ).
        with( host1, '/sbin/zonename' ).
        and_return( ret2 )

      expect( subject ).to receive( :hosts= ).with( [ host1 ] )

      subject.confine :to, :platform => 'solaris' do |host|
        subject.on( host, '/sbin/zonename' ).stdout =~ /:global/
      end
    end
  end

  describe '#select_hosts' do
    let(:logger) { double.as_null_object }
    before do
      allow( subject ).to receive( :logger ).and_return( logger )
    end

    it 'it returns an empty array if there are no applicable hosts' do
      hosts = [ {'thing' => 'foo'}, {'thing' => 'bar'} ]

      expect(subject.select_hosts( {'thing' => 'nope'}, hosts )).to be == []
    end

    it 'selects hosts that match a list of criteria' do
      hosts = [ {'thing' => 'foo'}, {'thing' => 'bar'}, {'thing' => 'baz'} ]

      expect(subject.select_hosts( {:thing => ['foo', 'baz']}, hosts )).to be == [ {'thing' => 'foo'}, {'thing' => 'baz'} ]
    end

    it 'selects hosts when a passed block returns true' do
      host1 = {'platform' => 'solaris1'}
      host2 = {'platform' => 'solaris2'}
      host3 = {'platform' => 'windows'}
      ret1 = double('result1')
      allow( ret1 ).to receive( :stdout ).and_return(':global')
      ret2 = double('result2')
      allow( ret2 ).to receive( :stdout ).and_return('a_zone')
      hosts = [ host1, host2, host3 ]
      expect( subject ).to receive( :hosts ).and_return( hosts )

      expect( subject ).to receive( :on ).with( host1, '/sbin/zonename' ).once.and_return( ret1 )
      expect( subject ).to receive( :on ).with( host2, '/sbin/zonename' ).once.and_return( ret2 )

      selected_hosts = subject.select_hosts 'platform' => 'solaris' do |host|
                             subject.on(host, '/sbin/zonename').stdout =~ /:global/
      end
      expect( selected_hosts ).to be == [ host1 ]
    end
  end

  describe '#apply_manifest_on' do
    it 'calls puppet' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :create_remote_file ).and_return( true )
      expect( subject ).to receive( :puppet ).
      #  with( 'apply', '--verbose', 'agent' ).
        and_return( 'puppet_command' )

      expect( subject ).to receive( :on ).
        with( agent, 'puppet_command',
              :acceptable_exit_codes => [0] )

      subject.apply_manifest_on( agent, 'class { "boo": }')
    end

    it 'operates on an array of hosts' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      the_hosts = [master, agent]

      expect( subject ).to receive( :create_remote_file ).twice.and_return( true )
      the_hosts.each do |host|
        expect( subject ).to receive( :puppet ).
          and_return( 'puppet_command' )

        expect( subject ).to receive( :on ).
          with( host, 'puppet_command', :acceptable_exit_codes => [0] )
      end

      result = subject.apply_manifest_on( the_hosts, 'include foobar' )
      expect(result).to be_an(Array)
    end

    it 'adds acceptable exit codes with :catch_failures' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :create_remote_file ).and_return( true )
      expect( subject ).to receive( :puppet ).
        and_return( 'puppet_command' )

      expect( subject ).to receive( :on ).
        with( agent, 'puppet_command',
              :acceptable_exit_codes => [0,2] )

      subject.apply_manifest_on( agent,
                                'class { "boo": }',
                                :catch_failures => true )
    end
    it 'allows acceptable exit codes through :catch_failures' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :create_remote_file ).and_return( true )
      expect( subject ).to receive( :puppet ).
        and_return( 'puppet_command' )

      expect( subject ).to receive( :on ).
        with( agent, 'puppet_command',
              :acceptable_exit_codes => [4,0,2] )

      subject.apply_manifest_on( agent,
                                'class { "boo": }',
                                :acceptable_exit_codes => [4],
                                :catch_failures => true )
    end
    it 'enforces a 0 exit code through :catch_changes' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :create_remote_file ).and_return( true )
      expect( subject ).to receive( :puppet ).
        and_return( 'puppet_command' )

      expect( subject ).to receive( :on ).with(
        agent,
        'puppet_command',
        :acceptable_exit_codes => [0]
      )

      subject.apply_manifest_on(
        agent,
        'class { "boo": }',
        :catch_changes => true
      )
    end
    it 'enforces a 2 exit code through :expect_changes' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :create_remote_file ).and_return( true )
      expect( subject ).to receive( :puppet ).
        and_return( 'puppet_command' )

      expect( subject ).to receive( :on ).with(
        agent,
        'puppet_command',
        :acceptable_exit_codes => [2]
      )

      subject.apply_manifest_on(
        agent,
        'class { "boo": }',
        :expect_changes => true
      )
    end
    it 'enforces exit codes through :expect_failures' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :create_remote_file ).and_return( true )
      expect( subject ).to receive( :puppet ).
        and_return( 'puppet_command' )

      expect( subject ).to receive( :on ).with(
        agent,
        'puppet_command',
        :acceptable_exit_codes => [1,4,6]
      )

      subject.apply_manifest_on(
        agent,
        'class { "boo": }',
        :expect_failures => true
      )
    end
    it 'enforces exit codes through :expect_failures' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expect {
        subject.apply_manifest_on(
          agent,
          'class { "boo": }',
          :expect_failures => true,
          :catch_failures  => true
        )
      }.to raise_error ArgumentError, /catch_failures.+expect_failures/
    end
    it 'enforces added exit codes through :expect_failures' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :create_remote_file ).and_return( true )
      expect( subject ).to receive( :puppet ).
        and_return( 'puppet_command' )

      expect( subject ).to receive( :on ).with(
        agent,
        'puppet_command',
        :acceptable_exit_codes => [1,2,3,4,5,6]
      )

      subject.apply_manifest_on(
        agent,
        'class { "boo": }',
        :acceptable_exit_codes => (1..5),
        :expect_failures       => true
      )
    end

    it 'can set the --parser future flag' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :create_remote_file ).and_return( true )

      expect( subject ).to receive( :on ) do |h, command, opts|
        cmdline = command.cmd_line( h )
        expect( h ).to be == agent
        expect( cmdline ).to include('puppet apply')
        expect( cmdline ).to include('--parser=future')
        expect( cmdline ).to include('--detailed-exitcodes')
        expect( cmdline ).to include('--verbose')
      end

      subject.apply_manifest_on(
        agent,
        'class { "boo": }',
        :acceptable_exit_codes => (1..5),
        :future_parser         => true,
        :expect_failures       => true
      )
    end

    it 'can set the --noops flag' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :create_remote_file ).and_return( true )
      expect( subject ).to receive( :on ) do |h, command, opts|
        cmdline = command.cmd_line( h )
        expect( h ).to be == agent
        expect( cmdline ).to include('puppet apply')
        expect( cmdline ).to include('--detailed-exitcodes')
        expect( cmdline ).to include('--verbose')
        expect( cmdline ).to include('--noop')
      end
      subject.apply_manifest_on(
        agent,
        'class { "boo": }',
        :acceptable_exit_codes => (1..5),
        :noop                  => true,
        :expect_failures       => true
      )
    end
  end

  it 'can set the --debug flag' do
    allow( subject ).to receive( :hosts ).and_return( hosts )
    allow( subject ).to receive( :create_remote_file ).and_return( true )
    expect( subject ).to receive( :on ) do |h, command, opts|
      cmdline = command.cmd_line( h )
      expect( h ).to be == agent
      expect( cmdline ).to include('puppet apply')
      expect( cmdline ).not_to include('--verbose')
      expect( cmdline ).to include('--debug')
    end
    subject.apply_manifest_on(
      agent,
      'class { "boo": }',
      :debug => true,
    )
  end

  describe "#apply_manifest" do
    it "delegates to #apply_manifest_on with the default host" do
      allow( subject ).to receive( :hosts ).and_return( hosts )

      expect( subject ).to receive( :apply_manifest_on ).with( master, 'manifest', {:opt => 'value'}).once

      subject.apply_manifest( 'manifest', {:opt => 'value'}  )

    end
  end

  describe '#stub_hosts_on' do
    it 'executes puppet on the host passed and ensures it is reverted' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      logger = double.as_null_object

      allow( subject ).to receive( :logger ).and_return( logger )
      expect( subject ).to receive( :on ).twice
      expect( subject ).to receive( :teardown ).and_yield
      expect( subject ).to receive( :puppet ).once.
        with( 'resource', 'host',
              'puppetlabs.com',
              'ensure=present', 'ip=127.0.0.1' )
      expect( subject ).to receive( :puppet ).once.
        with( 'resource', 'host',
              'puppetlabs.com',
              'ensure=absent' )

      subject.stub_hosts_on( make_host('my_host', {}), 'puppetlabs.com' => '127.0.0.1' )
    end
  end

  describe "#stub_hosts" do
    it "delegates to stub_hosts_on with the default host" do
      allow( subject ).to receive( :hosts ).and_return( hosts )

      expect( subject ).to receive( :stub_hosts_on ).with( master, 'ipspec' ).once

      subject.stub_hosts( 'ipspec'  )

    end
  end

  describe '#stub_forge_on' do
    it 'stubs forge.puppetlabs.com with the value of `forge`' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      host = make_host('my_host', {})
      expect( Resolv ).to receive( :getaddress ).
        with( 'my_forge.example.com' ).and_return( '127.0.0.1' )
      expect( subject ).to receive( :stub_hosts_on ).
        with( host, 'forge.puppetlabs.com' => '127.0.0.1' )
      expect( subject ).to receive( :stub_hosts_on ).
        with( host, 'forgeapi.puppetlabs.com' => '127.0.0.1' )

      subject.stub_forge_on( host, 'my_forge.example.com' )
    end
  end

  describe "#stub_forge" do
    it "delegates to stub_forge_on with the default host" do
      allow( subject ).to receive( :options ).and_return( {} )
      allow( subject ).to receive( :hosts ).and_return( hosts )

      expect( subject ).to receive( :stub_forge_on ).with( master, nil ).once

      subject.stub_forge( )

    end
  end

  describe 'version_is_less' do

    it 'reports 3.0.0-160-gac44cfb is not less than 3.0.0' do
      expect( subject.version_is_less( '3.0.0-160-gac44cfb', '3.0.0' ) ).to be === false
    end

    it 'reports 3.0.0-160-gac44cfb is not less than 2.8.2' do
      expect( subject.version_is_less( '3.0.0-160-gac44cfb', '2.8.2' ) ).to be === false
    end

    it 'reports 3.0.0 is less than 3.0.0-160-gac44cfb' do
      expect( subject.version_is_less( '3.0.0', '3.0.0-160-gac44cfb' ) ).to be === true
    end

    it 'reports 2.8.2 is less than 3.0.0-160-gac44cfb' do
      expect( subject.version_is_less( '2.8.2', '3.0.0-160-gac44cfb' ) ).to be === true
    end

    it 'reports 2.8 is less than 3.0.0-160-gac44cfb' do
      expect( subject.version_is_less( '2.8', '3.0.0-160-gac44cfb' ) ).to be === true
    end

    it 'reports 2.8 is less than 2.9' do
      expect( subject.version_is_less( '2.8', '2.9' ) ).to be === true
    end
  end

  describe "#stop_agent_on" do
    let( :result_fail ) { Beaker::Result.new( [], "" ) }
    let( :result_pass ) { Beaker::Result.new( [], "" ) }
    before :each do
      allow( subject ).to receive( :sleep ).and_return( true )
      result_fail.stdout = 'stdout'
      result_fail.stderr = 'stderr'
      result_fail.exit_code = 1
      result_pass.stdout = 'stdout'
      result_pass.stderr = 'stderr'
      result_pass.exit_code = 0
    end

    it 'runs the pe-puppet on a system without pe-puppet-agent' do
      vardir = '/var'
      deb_agent = make_host( 'deb', :platform => 'debian-7-amd64' )
      allow( deb_agent ).to receive( :puppet ).and_return( { 'vardir' => vardir } )

      allow( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :on ).with( deb_agent, "[ -e '#{vardir}/state/agent_catalog_run.lock' ]", :acceptable_exit_codes => [0,1] ).once.and_return( result_fail )
      expect( subject ).to receive( :on ).with( deb_agent, "[ -e /etc/init.d/pe-puppet-agent ]", :acceptable_exit_codes => [0,1] ).once.and_return( result_fail )
      expect( subject ).to receive( :puppet_resource ).with( "service", "pe-puppet", "ensure=stopped").once
      expect( subject ).to receive( :on ).once

      subject.stop_agent_on( deb_agent )

    end

    it 'runs the pe-puppet-agent on a unix system with pe-puppet-agent' do
      vardir = '/var'
      el_agent = make_host( 'el', :platform => 'el-5-x86_64' )
      allow( el_agent ).to receive( :puppet ).and_return( { 'vardir' => vardir } )

      allow( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject ).to receive( :on ).with( el_agent, "[ -e '#{vardir}/state/agent_catalog_run.lock' ]", :acceptable_exit_codes => [0,1] ).once.and_return( result_fail )
      expect( subject ).to receive( :on ).with( el_agent, "[ -e /etc/init.d/pe-puppet-agent ]", :acceptable_exit_codes => [0,1] ).once.and_return( result_pass )
      expect( subject ).to receive( :puppet_resource ).with("service", "pe-puppet-agent", "ensure=stopped").once
      expect( subject ).to receive( :on ).once

      subject.stop_agent_on( el_agent )
    end

  end

  describe "#stop_agent" do
    it 'delegates to #stop_agent_on with default host' do
      allow( subject ).to receive( :hosts ).and_return( hosts )

      expect( subject ).to receive( :stop_agent_on ).with( master ).once

      subject.stop_agent( )

    end
  end

  describe "#sign_certificate_for" do
    it 'signs certs' do
      allow( subject ).to receive( :sleep ).and_return( true )

      result.stdout = "+ \"#{agent}\""
      allow( subject ).to receive( :hosts ).and_return( hosts )

      allow( subject ).to receive( :puppet ) do |arg|
        arg
      end

      expect( subject ).to receive( :on ).with( master, "cert --sign --all --allow-dns-alt-names", :acceptable_exit_codes => [0,24]).once
      expect( subject ).to receive( :on ).with( master, "cert --list --all").once.and_return( result )

      subject.sign_certificate_for( agent )
    end

    it 'retries 11 times before quitting' do
      allow( subject ).to receive( :sleep ).and_return( true )

      result.stdout = " \"#{agent}\""
      allow( subject ).to receive( :hosts ).and_return( hosts )

      allow( subject ).to receive( :puppet ) do |arg|
        arg
      end

      expect( subject ).to receive( :on ).with( master, "cert --sign --all --allow-dns-alt-names", :acceptable_exit_codes => [0,24]).exactly( 11 ).times
      expect( subject ).to receive( :on ).with( master, "cert --list --all").exactly( 11 ).times.and_return( result )
      expect( subject ).to receive( :fail_test ).once

      subject.sign_certificate_for( agent )
    end

  end

  describe "#sign_certificate" do
    it 'delegates to #sign_certificate_for with the default host' do
      allow( subject ).to receive( :hosts ).and_return( hosts )

      expect( subject ).to receive( :sign_certificate_for ).with( master ).once

      subject.sign_certificate(  )
    end
  end

  describe '#with_puppet_running_on' do
    let(:test_case_path) { 'testcase/path' }
    let(:tmpdir_path) { '/tmp/tmpdir' }
    let(:is_pe) { false }
    let(:use_service) { false }
    let(:platform) { 'redhat' }
    let(:host) do
      FakeHost.create('fakevm', "#{platform}-version-arch",
        'type' => is_pe ? 'pe': 'git',
        'use-service' => use_service
      )
    end

    def stub_host_and_subject_to_allow_the_default_testdir_argument_to_be_created
      subject.instance_variable_set(:@path, test_case_path)
      allow( host ).to receive(:tmpdir).and_return(tmpdir_path)
      allow( host ).to receive(:file_exist?).and_return(true)
      allow( subject ).to receive( :options ).and_return( {} )
    end

    before do
      stub_host_and_subject_to_allow_the_default_testdir_argument_to_be_created
      allow( subject ).to receive(:curl_with_retries)
    end

    it "raises an ArgumentError if you try to submit a String instead of a Hash of options" do
      expect { subject.with_puppet_running_on(host, '--foo --bar') }.to raise_error(ArgumentError, /conf_opts must be a Hash. You provided a String: '--foo --bar'/)
    end

    it 'raises the early_exception if backup_the_file fails' do
      expect( subject ).to receive(:backup_the_file).and_raise(RuntimeError.new('puppet conf backup failed'))
      expect {
        subject.with_puppet_running_on(host, {})
      }.to raise_error(RuntimeError, /puppet conf backup failed/)
    end

    describe 'with puppet-server' do
      let(:default_confdir) { "/etc/puppet" }
      let(:default_vardir) { "/var/lib/puppet" }

      let(:custom_confdir) { "/tmp/etc/puppet" }
      let(:custom_vardir) { "/tmp/var/lib/puppet" }

      let(:command_line_args) {"--vardir=#{custom_vardir} --confdir=#{custom_confdir}"}
      let(:conf_opts) { {:__commandline_args__ => command_line_args,
                         :is_puppetserver => true}}

      let(:default_puppetserver_opts) {{ "jruby-puppet" => {
        "master-conf-dir" => default_confdir,
        "master-var-dir" => default_vardir,
      }}}

      let(:custom_puppetserver_opts) {{ "jruby-puppet" => {
        "master-conf-dir" => custom_confdir,
        "master-var-dir" => custom_vardir,
      }}}

      let(:puppetserver_conf) { "/etc/puppetserver/conf.d/puppetserver.conf" }
      let(:logger) { double }

      def stub_post_setup
        allow( subject ).to receive( :restore_puppet_conf_from_backup)
        allow( subject ).to receive( :bounce_service)
        allow( subject ).to receive( :stop_puppet_from_source_on)
        allow( subject ).to receive( :dump_puppet_log)
        allow( subject ).to receive( :restore_puppet_conf_from_backup)
        allow( subject ).to receive( :puppet_master_started)
        allow( subject ).to receive( :start_puppet_from_source_on!)
        allow( subject ).to receive( :lay_down_new_puppet_conf)
        allow( subject ).to receive( :logger) .and_return( logger )
        allow( logger ).to receive( :error)
        allow( logger ).to receive( :debug)
      end

      before do
        stub_post_setup
        allow( subject ).to receive( :options) .and_return( {:is_puppetserver => true})
        allow( subject ).to receive( :modify_tk_config)
        allow( host ).to receive(:puppet).with('master') .and_return({'confdir' => default_confdir,
                                                       'vardir' => default_vardir})
      end

      describe 'and command line args passed' do
        it 'modifies SUT trapperkeeper configuration w/ command line args' do
          expect( subject ).to receive( :modify_tk_config).with(host, puppetserver_conf,
                                                          custom_puppetserver_opts)
          subject.with_puppet_running_on(host, conf_opts)
        end
      end

      describe 'and no command line args passed' do
        let(:command_line_args) { nil }
        it 'modifies SUT trapperkeeper configuration w/ puppet defaults' do
          expect( subject ).to receive( :modify_tk_config).with(host, puppetserver_conf,
                                                          default_puppetserver_opts)
          subject.with_puppet_running_on(host, conf_opts)
        end
      end
    end

    describe "with valid arguments" do
      before do
        expect( Tempfile ).to receive(:open).with('beaker')
      end

      context 'for pe hosts' do
        let(:is_pe) { true }
        let(:service_restart) { true }

        it 'bounces puppet twice' do
          subject.with_puppet_running_on(host, {})
          expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=running/).exactly(2).times
          expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=stopped/).exactly(2).times
        end

        it 'yields to a block after bouncing service' do
          execution = 0
          allow( subject ).to receive(:curl_with_retries)
          expect do
            subject.with_puppet_running_on(host, {}) do
              expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=running/).exactly(1).times
              expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=stopped/).exactly(1).times
              execution += 1
            end
          end.to change { execution }.by(1)
          expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=running/).exactly(2).times
          expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=stopped/).exactly(2).times
        end
      end

      context 'for foss packaged hosts using passenger' do
        before(:each) do
          host.uses_passenger!
        end

        it 'bounces puppet twice' do
          allow( subject ).to receive(:curl_with_retries)
          subject.with_puppet_running_on(host, {})
          expect(host).to execute_commands_matching(/apache2ctl graceful/).exactly(2).times
        end

        it 'yields to a block after bouncing service' do
          execution = 0
          allow( subject ).to receive(:curl_with_retries)
          expect do
            subject.with_puppet_running_on(host, {}) do
              expect(host).to execute_commands_matching(/apache2ctl graceful/).once
              execution += 1
            end
          end.to change { execution }.by(1)
          expect(host).to execute_commands_matching(/apache2ctl graceful/).exactly(2).times
        end
      end

      context 'for foss packaged hosts using webrick' do
        let(:use_service) { true }

        it 'stops and starts master using service scripts' do
          allow( subject ).to receive(:curl_with_retries)
          subject.with_puppet_running_on(host, {})
          expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=running/).exactly(2).times
          expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=stopped/).exactly(2).times
        end

        it 'yields to a block after stopping and starting service' do
          execution = 0
          expect do
            subject.with_puppet_running_on(host, {}) do
              expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=running/).once
              expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=stopped/).once
              execution += 1
            end
          end.to change { execution }.by(1)
          expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=running/).exactly(2).times
          expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=stopped/).exactly(2).times
        end
      end

      context 'running from source' do
        let('use-service') { false }

        it 'does not try to stop if not started' do
          expect( subject ).to receive(:start_puppet_from_source_on!).and_return false
          expect( subject ).to_not receive(:stop_puppet_from_source_on)

          subject.with_puppet_running_on(host, {})
        end

        context 'successfully' do
          before do
            expect( host ).to receive(:port_open?).with(8140).and_return(true)
          end

          it 'starts puppet from source' do
            subject.with_puppet_running_on(host, {})
          end

          it 'stops puppet from source' do
            subject.with_puppet_running_on(host, {})
            expect(host).to execute_commands_matching(/^kill [^-]/).once
            expect(host).to execute_commands_matching(/^kill -0/).once
          end

          it 'yields between starting and stopping' do
            execution = 0
            expect do
              subject.with_puppet_running_on(host, {}) do
                expect(host).to execute_commands_matching(/^puppet master/).once
                execution += 1
              end
            end.to change { execution }.by(1)
            expect(host).to execute_commands_matching(/^kill [^-]/).once
            expect(host).to execute_commands_matching(/^kill -0/).once
          end

          it 'passes on commandline args' do
            subject.with_puppet_running_on(host, {:__commandline_args__ => '--with arg'})
            expect(host).to execute_commands_matching(/^puppet master --with arg/).once
          end
        end
      end

      describe 'backup and restore of puppet.conf' do
        let(:original_location) { "#{host['puppetpath']}/puppet.conf" }
        let(:backup_location) { "#{tmpdir_path}/puppet.conf.bak" }
        let(:new_location) { "#{tmpdir_path}/puppet.conf" }

        context 'when a puppetservice is used' do
          let(:use_service) { true }

          it 'backs up puppet.conf' do
            subject.with_puppet_running_on(host, {})
            expect(host).to execute_commands_matching(/cp #{original_location} #{backup_location}/).once
            expect(host).to execute_commands_matching(/cat #{new_location} > #{original_location}/).once
          end

          it 'restores puppet.conf before restarting' do
            subject.with_puppet_running_on(host, {})
            expect(host).to execute_commands_matching_in_order(/cat '#{backup_location}' > '#{original_location}'/,
                                                               /ensure=stopped/,
                                                               /ensure=running/)
          end
        end

        context 'when a puppetservice is not used' do
          before do
            expect( host ).to receive(:port_open?).with(8140).and_return(true)
          end

          it 'backs up puppet.conf' do
            subject.with_puppet_running_on(host, {})
            expect(host).to execute_commands_matching(/cp #{original_location} #{backup_location}/).once
            expect(host).to execute_commands_matching(/cat #{new_location} > #{original_location}/).once
          end

          it 'restores puppet.conf after restarting when a puppetservice is not used' do
            subject.with_puppet_running_on(host, {})
            expect(host).to execute_commands_matching_in_order(/kill [^-]/,
                                                               /cat '#{backup_location}' > '#{original_location}'/m)
          end

          it "doesn't restore a non-existent file" do
            allow( subject ).to receive(:backup_the_file)
            subject.with_puppet_running_on(host, {})
            expect(host).to execute_commands_matching(/rm -f '#{original_location}'/)
          end
        end
      end

      describe 'handling failures' do

        let(:logger) { double.as_null_object }
        before do
          allow( subject ).to receive( :logger ).and_return( logger )
          expect( subject ).to receive(:stop_puppet_from_source_on).and_raise(RuntimeError.new('Also failed in teardown.'))
        end

        it 'does not swallow an exception raised from within test block if ensure block also fails' do
          expect( host ).to receive(:port_open?).with(8140).and_return(true)

          expect( subject.logger ).to receive(:error).with(/Raised during attempt to teardown.*Also failed in teardown/)

          expect do
            subject.with_puppet_running_on(host, {}) { raise 'Failed while yielding.' }
          end.to raise_error(RuntimeError, /failed.*because.*Failed while yielding./)
        end

        it 'dumps the puppet logs if there is an error in the teardown' do
          expect( host ).to receive(:port_open?).with(8140).and_return(true)

          expect( subject.logger ).to receive(:notify).with(/Dumping master log/)

          expect do
            subject.with_puppet_running_on(host, {})
          end.to raise_error(RuntimeError, /Also failed in teardown/)
        end

        it 'does not mask the teardown error with an error from dumping the logs' do
          expect( host ).to receive(:port_open?).with(8140).and_return(true)

          expect( subject.logger ).to receive(:notify).with(/Dumping master log/).and_raise("Error from dumping logs")

          expect do
            subject.with_puppet_running_on(host, {})
          end.to raise_error(RuntimeError, /Also failed in teardown/)
        end

        it 'does not swallow a teardown exception if no earlier exception was raised' do
          expect( host ).to receive(:port_open?).with(8140).and_return(true)
          expect( subject.logger).to_not receive(:error)
          expect do
            subject.with_puppet_running_on(host, {})
          end.to raise_error(RuntimeError, 'Also failed in teardown.')
        end
      end
    end
  end

  describe '#with_puppet_running' do
    it 'delegates to #with_puppet_running_on with the default host' do
      allow( subject ).to receive( :hosts ).and_return( hosts )

      expect( subject ).to receive( :with_puppet_running_on ).with( master, {:opt => 'value'}, '/dir').once

      subject.with_puppet_running( {:opt => 'value'}, '/dir'  )


    end
  end

  describe '#fact_on' do
    it 'retrieves a fact on a single host' do
      result.stdout = "family\n"
      expect( subject ).to receive(:facter).with('osfamily',{}).once
      expect( subject ).to receive(:on).and_return(result)

      expect( subject.fact_on('host','osfamily') ).to be === result.stdout.chomp
    end

    it 'retrieves an array of facts from multiple hosts' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      times = hosts.length
      result.stdout = "family\n"
      hosts.each do |host|
        expect( host ).to receive(:exec).and_return(result)
      end

      expect( subject.fact_on(hosts,'osfamily') ).to be === [result.stdout.chomp] * hosts.length

    end
  end

  describe '#fact' do
    it 'delegates to #fact_on with the default host' do
      allow( subject ).to receive(:hosts).and_return(hosts)
      expect( subject ).to receive(:fact_on).with(master,"osfamily",{}).once

      subject.fact('osfamily')
    end
  end

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
