require 'spec_helper'

class ClassMixedWithDSLHelpers
  include Beaker::DSL::Helpers
  include Beaker::DSL::Wrappers
  include Beaker::DSL::Roles

  def logger
    @logger ||= RSpec::Mocks::Mock.new('logger').as_null_object
  end
end

describe ClassMixedWithDSLHelpers do
  let( :opts )     { Beaker::Options::Presets.env_vars }
  let( :command )  { 'ls' }
  let( :host ) { double.as_null_object }
  let( :result ) { Beaker::Result.new( host, command ) }

  let( :master ) { make_host( 'master',   :roles => %w( master agent )    ) }
  let( :agent )  { make_host( 'agent',    :roles => %w( agent )           ) }
  let( :custom ) { make_host( 'custom',   :roles => %w( custom agent )    ) }
  let( :dash )   { make_host( 'console',  :roles => %w( dashboard agent ) ) }
  let( :db )     { make_host( 'db',       :roles => %w( database agent )  ) }
  let( :hosts ) { [ master, agent, dash, db, custom ] }

  describe '#on' do

    before :each do
      result.stdout = 'stdout'
      result.stderr = 'stderr'
      result.exit_code = 0
    end

    it 'allows the environment the command is run within to be specified' do

      Beaker::Command.should_receive( :new ).
        with( 'ls ~/.bin', [], {'ENV' => { :HOME => '/tmp/test_home' }} )

      subject.on( host, 'ls ~/.bin', :environment => {:HOME => '/tmp/test_home' } )
    end

    it 'if the host is a String Object, finds the matching hosts with that String as role' do
      subject.stub( :hosts ).and_return( hosts )

      master.should_receive( :exec ).once

      subject.on( 'master', 'echo hello')

    end

    it 'if the host is a Symbol Object, finds the matching hsots with that Symbol as role' do
      subject.stub( :hosts ).and_return( hosts )

      master.should_receive( :exec ).once

      subject.on( :master, 'echo hello')

    end

    it 'delegates to itself for each host passed' do
      expected = []
      hosts.each_with_index do |host, i|
        expected << i
        host.should_receive( :exec ).and_return( i )
      end

      results = subject.on( hosts, command )
      expect( results ).to be == expected
    end

    context 'upon command completion' do
      before :each do
        host.should_receive( :exec ).and_return( result )
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
        host.should_receive( :exec ).and_return( result )
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
        host.should_receive( :exec ).and_return( result )
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

  describe "shell" do
    it 'delegates to #on with the default host' do
      subject.stub( :hosts ).and_return( hosts )

      subject.should_receive( :on ).with( master, "echo hello", {}).once

      subject.shell( "echo hello" )
    end
  end

  describe '#scp_from' do
    it 'delegates to the host' do
      subject.should_receive( :logger ).exactly( hosts.length ).times
      result.should_receive( :log ).exactly( hosts.length ).times

      hosts.each do |host|
        host.should_receive( :do_scp_from ).and_return( result )
      end

      subject.scp_from( hosts, '/var/log/my.log', 'log/my.log' )
    end
  end

  describe '#scp_to' do
    it 'delegates to the host' do
      subject.should_receive( :logger ).exactly( hosts.length ).times
      result.should_receive( :log ).exactly( hosts.length ).times

      hosts.each do |host|
        host.should_receive( :do_scp_to ).and_return( result )
      end

      subject.scp_to( hosts, '/var/log/my.log', 'log/my.log' )
    end
  end

  describe '#create_remote_file' do
    it 'scps the contents passed in to the hosts' do
      my_opts = { :silent => true }
      tmpfile = double

      tmpfile.should_receive( :path ).exactly( 2 ).times.
        and_return( '/local/path/to/blah' )

      Tempfile.should_receive( :open ).and_yield( tmpfile )

      File.should_receive( :open )

      subject.should_receive( :scp_to ).
        with( hosts, '/local/path/to/blah', '/remote/path', my_opts )

      subject.create_remote_file( hosts, '/remote/path', 'blah', my_opts )
    end
  end

  describe '#run_script_on' do
    it 'scps the script to a tmpdir and executes it on host(s)' do
      subject.should_receive( :scp_to )
      subject.should_receive( :on )
      subject.run_script_on( 'host', '~/.bin/make-enterprisy' )
    end
  end

  describe '#run_script' do
    it 'delegates to #run_script_on with the default host' do
      subject.stub( :hosts ).and_return( hosts )

      subject.should_receive( :run_script_on ).with( master, "/tmp/test.sh", {}).once

      subject.run_script( '/tmp/test.sh' )
    end
  end

  describe '#puppet_module_install_on' do
    it 'scps the module to the module dir' do
      subject.stub( :hosts ).and_return( hosts )

      subject.should_receive( :scp_to ).with( master, '/module', '/etc/puppet/modules/test' ).once
      subject.puppet_module_install_on( master, {:source => '/module', :module_name => 'test'} )
    end
  end

  describe '#puppet_module_install' do
    it 'delegates to #puppet_module_install_on with the hosts list' do
      subject.stub( :hosts ).and_return( hosts )

      subject.should_receive( :puppet_module_install_on ).with( hosts, {:source => '/module', :module_name => 'test'}).once

      subject.puppet_module_install( {:source => '/module', :module_name => 'test'} )
    end
  end

  describe 'confine' do
    let(:logger) { double.as_null_object }
    before do
      subject.stub( :logger ).and_return( logger )
    end

    it 'skips the test if there are no applicable hosts' do
      subject.stub( :hosts ).and_return( [] )
      subject.stub( :hosts= )
      logger.should_receive( :warn )
      subject.should_receive( :skip_test ).
        with( 'No suitable hosts found' )

      subject.confine( :to, {} )
    end

    it 'raises when given mode is not :to or :except' do
      subject.stub( :hosts )
      subject.stub( :hosts= )

      expect {
        subject.confine( :regardless, {:thing => 'value'} )
      }.to raise_error( 'Unknown option regardless' )
    end

    it 'rejects hosts that do not meet simple hash criteria' do
      hosts = [ {'thing' => 'foo'}, {'thing' => 'bar'} ]

      subject.should_receive( :hosts ).and_return( hosts )
      subject.should_receive( :hosts= ).
        with( [ {'thing' => 'foo'} ] )

      subject.confine :to, :thing => 'foo'
    end

    it 'rejects hosts that match a list of criteria' do
      hosts = [ {'thing' => 'foo'}, {'thing' => 'bar'}, {'thing' => 'baz'} ]

      subject.should_receive( :hosts ).and_return( hosts )
      subject.should_receive( :hosts= ).
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

      subject.should_receive( :hosts ).and_return( hosts )
      subject.should_receive( :on ).
        with( host1, '/sbin/zonename' ).
        and_return( ret1 )
      subject.should_receive( :on ).
        with( host1, '/sbin/zonename' ).
        and_return( ret2 )

      subject.should_receive( :hosts= ).with( [ host1 ] )

      subject.confine :to, :platform => 'solaris' do |host|
        subject.on( host, '/sbin/zonename' ).stdout =~ /:global/
      end
    end
  end

  describe '#apply_manifest_on' do
    it 'calls puppet' do
      subject.should_receive( :create_remote_file ).and_return( true )
      subject.should_receive( :puppet ).
        with( 'apply', '--verbose', 'agent' ).
        and_return( 'puppet_command' )

      subject.should_receive( :on ).
        with( agent, 'puppet_command',
              :acceptable_exit_codes => [0] )

      subject.apply_manifest_on( agent, 'class { "boo": }')
    end

    it 'operates on an array of hosts' do
      the_hosts = [master, agent]

      subject.should_receive( :create_remote_file ).twice.and_return( true )
      the_hosts.each do |host|
        subject.should_receive( :puppet ).
          with( 'apply', '--verbose', host.to_s ).
          and_return( 'puppet_command' )

        subject.should_receive( :on ).
          with( host, 'puppet_command',
                :acceptable_exit_codes => [0, 1] ).ordered
      end

      result = subject.apply_manifest_on( the_hosts, 'include foobar', :acceptable_exit_codes => [0,1] )
      result.should(be_an(Array))
    end

    it 'adds acceptable exit codes with :catch_failures' do
      subject.should_receive( :create_remote_file ).and_return( true )
      subject.should_receive( :puppet ).
        with( 'apply', '--verbose', '--trace', '--detailed-exitcodes', 'agent' ).
        and_return( 'puppet_command' )

      subject.should_receive( :on ).
        with( agent, 'puppet_command',
              :acceptable_exit_codes => [0,2] )

      subject.apply_manifest_on( agent,
                                'class { "boo": }',
                                :trace => true,
                                :catch_failures => true )
    end
    it 'allows acceptable exit codes through :catch_failures' do
      subject.should_receive( :create_remote_file ).and_return( true )
      subject.should_receive( :puppet ).
        with( 'apply', '--verbose', '--trace', '--detailed-exitcodes', 'agent' ).
        and_return( 'puppet_command' )

      subject.should_receive( :on ).
        with( agent, 'puppet_command',
              :acceptable_exit_codes => [4,0,2] )

      subject.apply_manifest_on( agent,
                                'class { "boo": }',
                                :acceptable_exit_codes => [4],
                                :trace => true,
                                :catch_failures => true )
    end
    it 'enforces a 0 exit code through :catch_changes' do
      subject.should_receive( :create_remote_file ).and_return( true )
      subject.should_receive( :puppet ).
        with( 'apply', '--verbose', '--trace', '--detailed-exitcodes', 'agent' ).
        and_return( 'puppet_command' )

      subject.should_receive( :on ).with(
        agent,
        'puppet_command',
        :acceptable_exit_codes => [0]
      )

      subject.apply_manifest_on(
        agent,
        'class { "boo": }',
        :trace         => true,
        :catch_changes => true
      )
    end
    it 'enforces a 2 exit code through :expect_changes' do
      subject.should_receive( :create_remote_file ).and_return( true )
      subject.should_receive( :puppet ).
        with( 'apply', '--verbose', '--trace', '--detailed-exitcodes', 'agent' ).
        and_return( 'puppet_command' )

      subject.should_receive( :on ).with(
        agent,
        'puppet_command',
        :acceptable_exit_codes => [2]
      )

      subject.apply_manifest_on(
        agent,
        'class { "boo": }',
        :trace         => true,
        :expect_changes => true
      )
    end
    it 'enforces exit codes through :expect_failures' do
      subject.should_receive( :create_remote_file ).and_return( true )
      subject.should_receive( :puppet ).
        with( 'apply', '--verbose', '--trace', '--detailed-exitcodes', 'agent' ).
        and_return( 'puppet_command' )

      subject.should_receive( :on ).with(
        agent,
        'puppet_command',
        :acceptable_exit_codes => [1,4,6]
      )

      subject.apply_manifest_on(
        agent,
        'class { "boo": }',
        :trace           => true,
        :expect_failures => true
      )
    end
    it 'enforces exit codes through :expect_failures' do
      expect {
        subject.apply_manifest_on(
          agent,
          'class { "boo": }',
          :trace           => true,
          :expect_failures => true,
          :catch_failures  => true
        )
      }.to raise_error ArgumentError, /catch_failures.+expect_failures/
    end
    it 'enforces added exit codes through :expect_failures' do
      subject.should_receive( :create_remote_file ).and_return( true )
      subject.should_receive( :puppet ).
        with( 'apply', '--verbose', '--trace', '--detailed-exitcodes', 'agent' ).
        and_return( 'puppet_command' )

      subject.should_receive( :on ).with(
        agent,
        'puppet_command',
        :acceptable_exit_codes => [1,2,3,4,5,6]
      )

      subject.apply_manifest_on(
        agent,
        'class { "boo": }',
        :acceptable_exit_codes => (1..5),
        :trace                 => true,
        :expect_failures       => true
      )
    end

    it 'can set the --parser future flag' do
      subject.should_receive( :create_remote_file ).and_return( true )
      subject.should_receive( :puppet ).
        with( 'apply', '--verbose', '--parser future', '--detailed-exitcodes', 'agent' ).
        and_return( 'puppet_command' )
      subject.should_receive( :on ).with(
        agent,
        'puppet_command',
        :acceptable_exit_codes => [1,2,3,4,5,6]
      )

      subject.apply_manifest_on(
        agent,
        'class { "boo": }',
        :acceptable_exit_codes => (1..5),
        :future_parser         => true,
        :expect_failures       => true
      )
    end
  end

  describe "#apply_manifest" do
    it "delegates to #apply_manifest_on with the default host" do
      subject.stub( :hosts ).and_return( hosts )

      subject.should_receive( :apply_manifest_on ).with( master, 'manifest', {:opt => 'value'}).once

      subject.apply_manifest( 'manifest', {:opt => 'value'}  )

    end
  end

  describe '#stub_hosts_on' do
    it 'executes puppet on the host passed and ensures it is reverted' do
      logger = double.as_null_object

      subject.stub( :logger ).and_return( logger )
      subject.should_receive( :on ).twice
      subject.should_receive( :teardown ).and_yield
      subject.should_receive( :puppet ).once.
        with( 'resource', 'host',
              'puppetlabs.com',
              'ensure=present', 'ip=127.0.0.1' )
      subject.should_receive( :puppet ).once.
        with( 'resource', 'host',
              'puppetlabs.com',
              'ensure=absent' )

      subject.stub_hosts_on( 'my_host', 'puppetlabs.com' => '127.0.0.1' )
    end
  end

  describe "#stub_hosts" do
    it "delegates to #stub_hosts_on with the default host" do
      subject.stub( :hosts ).and_return( hosts )

      subject.should_receive( :stub_hosts_on ).with( master, 'ipspec' ).once

      subject.stub_hosts( 'ipspec'  )

    end
  end

  describe '#stub_forge_on' do
    it 'stubs forge.puppetlabs.com with the value of `forge`' do
      subject.stub( :options ).and_return( {} )
      Resolv.should_receive( :getaddress ).
        with( 'my_forge.example.com' ).and_return( '127.0.0.1' )
      subject.should_receive( :stub_hosts_on ).
        with( 'my_host', 'forge.puppetlabs.com' => '127.0.0.1' )
      subject.should_receive( :stub_hosts_on ).
        with( 'my_host', 'forgeapi.puppetlabs.com' => '127.0.0.1' )

      subject.stub_forge_on( 'my_host', 'my_forge.example.com' )
    end
  end

  describe "#stub_forge" do
    it "delegates to #stub_forge_on with the default host" do
      subject.stub( :options ).and_return( {} )
      subject.stub( :hosts ).and_return( hosts )

      subject.should_receive( :stub_forge_on ).with( master, nil ).once

      subject.stub_forge( )

    end
  end

  describe "#stop_agent_on" do
    let( :result_fail ) { Beaker::Result.new( [], "" ) }
    let( :result_pass ) { Beaker::Result.new( [], "" ) }
    before :each do
      subject.stub( :sleep ).and_return( true )
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
      deb_agent.stub( :puppet ).and_return( { 'vardir' => vardir } )

      subject.should_receive( :on ).with( deb_agent, "[ -e '#{vardir}/state/agent_catalog_run.lock' ]", :acceptable_exit_codes => [0,1] ).once.and_return( result_fail )
      subject.should_receive( :on ).with( deb_agent, "[ -e /etc/init.d/pe-puppet-agent ]", :acceptable_exit_codes => [0,1] ).once.and_return( result_fail )
      subject.should_receive( :puppet_resource ).with( "service", "pe-puppet", "ensure=stopped").once
      subject.should_receive( :on ).once

      subject.stop_agent_on( deb_agent )

    end

    it 'runs the pe-puppet-agent on a unix system with pe-puppet-agent' do
      vardir = '/var'
      el_agent = make_host( 'el', :platform => 'el-5-x86_64' )
      el_agent.stub( :puppet ).and_return( { 'vardir' => vardir } )

      subject.should_receive( :on ).with( el_agent, "[ -e '#{vardir}/state/agent_catalog_run.lock' ]", :acceptable_exit_codes => [0,1] ).once.and_return( result_fail )
      subject.should_receive( :on ).with( el_agent, "[ -e /etc/init.d/pe-puppet-agent ]", :acceptable_exit_codes => [0,1] ).once.and_return( result_pass )
      subject.should_receive( :puppet_resource ).with("service", "pe-puppet-agent", "ensure=stopped").once
      subject.should_receive( :on ).once

      subject.stop_agent_on( el_agent )
    end

  end

  describe "#stop_agent" do
    it 'delegates to #stop_agent_on with default host' do
      subject.stub( :hosts ).and_return( hosts )

      subject.should_receive( :stop_agent_on ).with( master ).once

      subject.stop_agent( )

    end
  end

  describe "#sign_certificate_for" do
    it 'signs certs' do
      subject.stub( :sleep ).and_return( true )

      result.stdout = "+ \"#{agent}\""
      subject.stub( :hosts ).and_return( hosts )

      subject.stub( :puppet ) do |arg|
        arg
      end

      subject.should_receive( :on ).with( master, "cert --sign --all", :acceptable_exit_codes => [0,24]).once
      subject.should_receive( :on ).with( master, "cert --list --all").once.and_return( result )


      subject.sign_certificate_for( agent )
    end

    it 'retries 11 times before quitting' do
      subject.stub( :sleep ).and_return( true )

      result.stdout = " \"#{agent}\""
      subject.stub( :hosts ).and_return( hosts )

      subject.stub( :puppet ) do |arg|
        arg
      end

      subject.should_receive( :on ).with( master, "cert --sign --all", :acceptable_exit_codes => [0,24]).exactly( 11 ).times
      subject.should_receive( :on ).with( master, "cert --list --all").exactly( 11 ).times.and_return( result )
      subject.should_receive( :fail_test ).once

      subject.sign_certificate_for( agent )
    end

  end

  describe "#sign_certificate" do
    it 'delegates to #sign_certificate_for with the default host' do
      subject.stub( :hosts ).and_return( hosts )

      subject.should_receive( :sign_certificate_for ).with( master ).once

      subject.sign_certificate(  )
    end
  end

  describe '#with_puppet_running_on' do
    let(:test_case_path) { 'testcase/path' }
    let(:tmpdir_path) { '/tmp/tmpdir' }
    let(:puppet_path) { '/puppet/path' }
    let(:puppetservice) { @ps || nil }
    let(:is_pe) { false }
    let(:host) do
      FakeHost.new(:pe => is_pe,
                   :options => {
        'puppetpath' => puppet_path,
        'puppetservice' => puppetservice,
        'platform' => 'el'
      })
    end

    def stub_host_and_subject_to_allow_the_default_testdir_argument_to_be_created
      subject.instance_variable_set(:@path, test_case_path)
      host.stub(:tmpdir).and_return(tmpdir_path)
      host.stub(:file_exist?).and_return(true)
    end

    before do
      stub_host_and_subject_to_allow_the_default_testdir_argument_to_be_created
    end

    it "raises an ArgumentError if you try to submit a String instead of a Hash of options" do
      expect { subject.with_puppet_running_on(host, '--foo --bar') }.to raise_error(ArgumentError, /conf_opts must be a Hash. You provided a String: '--foo --bar'/)
    end

    it 'raises the early_exception if backup_the_file fails' do
      subject.should_receive(:backup_the_file).and_raise(RuntimeError.new('puppet conf backup failed'))
      expect {
        subject.with_puppet_running_on(host, {})
      }.to raise_error(RuntimeError, /puppet conf backup failed/)
    end

    describe "with valid arguments" do
      before do
        Tempfile.should_receive(:open).with('beaker')
      end

      context 'with puppetservice and service-path defined' do
        let(:puppetservice) { 'whatever' }

        it 'bounces puppet twice' do
          subject.with_puppet_running_on(host, {})
          expect(host).to execute_commands_matching(/#{@ps} restart/).exactly(2).times
        end

        it 'yield to a block after bouncing service' do
          execution = 0
          expect do
            subject.with_puppet_running_on(host, {}) do
              expect(host).to execute_commands_matching(/#{@ps} restart/).once
              execution += 1
            end
          end.to change { execution }.by(1)
          expect(host).to execute_commands_matching(/#{@ps} restart/).exactly(2).times
        end
      end

      context 'running from source' do

        it 'does not try to stop if not started' do
          subject.should_receive(:start_puppet_from_source_on!).and_return false
          subject.should_not_receive(:stop_puppet_from_source_on)

          subject.with_puppet_running_on(host, {})
        end

        context 'successfully' do
          before do
            host.should_receive(:port_open?).with(8140).and_return(true)
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
        let(:original_location) { "#{puppet_path}/puppet.conf" }
        let(:backup_location) { "#{tmpdir_path}/puppet.conf.bak" }
        let(:new_location) { "#{tmpdir_path}/puppet.conf" }

        before do
          host.should_receive(:port_open?).with(8140).and_return(true)
        end

        it 'backs up puppet.conf' do
          subject.with_puppet_running_on(host, {})
          expect(host).to execute_commands_matching(/cp #{original_location} #{backup_location}/).once
          expect(host).to execute_commands_matching(/cat #{new_location} > #{original_location}/).once

        end

        it 'restores puppet.conf' do
          subject.with_puppet_running_on(host, {})
          expect(host).to execute_commands_matching(/cat '#{backup_location}' > '#{original_location}'/).once
        end

        it "doesn't restore a non-existent file" do
          subject.stub(:backup_the_file)
          subject.with_puppet_running_on(host, {})
          expect(host).to execute_commands_matching(/rm -f '#{original_location}'/)
        end
      end

      describe 'handling failures' do
        before do
          subject.should_receive(:stop_puppet_from_source_on).and_raise(RuntimeError.new('Also failed in teardown.'))
        end

        it 'does not swallow an exception raised from within test block if ensure block also fails' do
          host.should_receive(:port_open?).with(8140).and_return(true)

          subject.logger.should_receive(:error).with(/Raised during attempt to teardown.*Also failed in teardown/)

          expect do
            subject.with_puppet_running_on(host, {}) { raise 'Failed while yielding.' }
          end.to raise_error(RuntimeError, /failed.*because.*Failed while yielding./)
        end

        it 'dumps the puppet logs if there is an error in the teardown' do
          host.should_receive(:port_open?).with(8140).and_return(true)

          subject.logger.should_receive(:notify).with(/Dumping master log/)

          expect do
            subject.with_puppet_running_on(host, {})
          end.to raise_error(RuntimeError, /Also failed in teardown/)
        end

        it 'does not mask the teardown error with an error from dumping the logs' do
          host.should_receive(:port_open?).with(8140).and_return(true)

          subject.logger.should_receive(:notify).with(/Dumping master log/).and_raise("Error from dumping logs")

          expect do
            subject.with_puppet_running_on(host, {})
          end.to raise_error(RuntimeError, /Also failed in teardown/)
        end

        it 'does not swallow a teardown exception if no earlier exception was raised' do
          host.should_receive(:port_open?).with(8140).and_return(true)
          subject.logger.should_not_receive(:error)
          expect do
            subject.with_puppet_running_on(host, {})
          end.to raise_error(RuntimeError, 'Also failed in teardown.')
        end
      end
    end
  end

  describe '#with_puppet_running' do
    it 'delegates to #with_puppet_running_on with the default host' do
      subject.stub( :hosts ).and_return( hosts )

      subject.should_receive( :with_puppet_running_on ).with( master, {:opt => 'value'}, '/dir').once

      subject.with_puppet_running( {:opt => 'value'}, '/dir'  )


    end
  end

  describe '#fact_on' do
    it 'retreives a fact on host(s)' do
      subject.should_receive(:facter).with('osfamily',{}).once
      subject.should_receive(:on).and_return(result)

      subject.fact_on('host','osfamily')
    end
  end

  describe '#fact' do
    it 'delegates to #fact_on with the default host' do
      subject.stub(:hosts).and_return(hosts)
      subject.should_receive(:fact_on).with(master,"osfamily",{}).once

      subject.fact('osfamily')
    end
  end


  describe 'copy_root_module_to' do
    def source_to_scp (source, target, items)
      subject.stub(:parse_for_moduleroot).and_return('/totalfake/testmodule')
      Dir.stub(:getpwd).and_return('/totalfake/testmodule')

      items = [items] unless items.kind_of?(Array)
      File.stub(:exists?).with(any_args()).and_return(false)
      File.stub(:directory?).with(any_args()).and_return(false)
      items.each do |item|
        source_item = File.join(source,item)
        File.stub(:exists?).with(source_item).and_return(true)
        options = {}
        if ['manifests','lib','templates','files'].include? item
          File.stub(:directory?).with(source_item).and_return(true)
          options = {:mkdir => true}
        end
        master.should_receive(:do_scp_to).with(source_item,target,options).ordered
      end
    end
    it 'should call scp with the correct info, with only providing host' do
      files = ['manifests','lib','templates','metadata.json','Modulefile','files']
      source_to_scp '/totalfake/testmodule',"#{master['puppetpath']}/modules/testmodule",files
      subject.stub(:parse_for_modulename).with(any_args()).and_return("testmodule")
      subject.copy_root_module_to(master)
    end
    it 'should call scp with the correct info, when specifying the modulename' do
      files = ['manifests','lib','metadata.json','Modulefile']
      source_to_scp '/totalfake/testmodule',"#{master['puppetpath']}/modules/bogusmodule",files
      subject.stub(:parse_for_modulename).and_return('testmodule')
      subject.copy_root_module_to(master,{:module_name =>"bogusmodule"})
    end
    it 'should call scp with the correct info, when specifying the target to a different path' do
      files = ['manifests','lib','templates','metadata.json','Modulefile','files']
      target = "/opt/shared/puppet/modules"
      source_to_scp '/totalfake/testmodule',"#{target}/testmodule",files
      subject.stub(:parse_for_modulename).and_return('testmodule')
      subject.copy_root_module_to(master,{:target_module_path => target})
    end
  end

  describe 'split_author_modulename' do
    it 'should return a correct modulename' do
      result =  subject.split_author_modulename('myname-test_43_module')
      expect(result[:author]).to eq('myname')
      expect(result[:module]).to eq('test_43_module')
    end
  end

  describe 'get_module_name' do
    it 'should return a has of author and modulename' do
      expect(subject.get_module_name('myname-test_43_module')).to eq('test_43_module')
    end
    it 'should return nil for invalid names' do
      expect(subject.get_module_name('myname-')).to eq(nil)
    end
  end

  describe 'parse_for_modulename' do
    directory = '/testfilepath/myname-testmodule'
    it 'should return name from metadata.json' do
      File.stub(:exists?).with("#{directory}/metadata.json").and_return(true)
      File.stub(:read).with("#{directory}/metadata.json").and_return(" {\"name\":\"myname-testmodule\"} ")
      subject.logger.should_receive(:debug).with("Attempting to parse Modulename from metadata.json")
      subject.logger.should_not_receive(:debug).with('Unable to determine name, returning null')
      subject.parse_for_modulename(directory).should eq('testmodule')
    end
    it 'should return name from Modulefile' do
      File.stub(:exists?).with("#{directory}/metadata.json").and_return(false)
      File.stub(:exists?).with("#{directory}/Modulefile").and_return(true)
      File.stub(:read).with("#{directory}/Modulefile").and_return("name    'myname-testmodule'  \nauthor   'myname'")
      subject.logger.should_receive(:debug).with("Attempting to parse Modulename from Modulefile")
      subject.logger.should_not_receive(:debug).with("Unable to determine name, returning null")
      expect(subject.parse_for_modulename(directory)).to eq('testmodule')
    end
  end

  describe 'parse_for_module_root' do
    directory = '/testfilepath/myname-testmodule'
    it 'should recersively go up the directory to find the module files' do
      File.stub(:exists?).with("#{directory}/acceptance/Modulefile").and_return(false)
      File.stub(:exists?).with("#{directory}/Modulefile").and_return(true)
      subject.logger.should_not_receive(:debug).with("At root, can't parse for another directory")
      subject.logger.should_receive(:debug).with("No Modulefile found at #{directory}/acceptance, moving up")
      expect(subject.parse_for_moduleroot("#{directory}/acceptance")).to eq(directory)
    end
    it 'should recersively go up the directory to find the module files' do
      File.stub(:exists?).and_return(false)
      subject.logger.should_receive(:debug).with("No Modulefile found at #{directory}, moving up")
      subject.logger.should_receive(:error).with("At root, can't parse for another directory")
      expect(subject.parse_for_moduleroot(directory)).to eq(nil)
    end

  end
end

module FakeFS
  class File < StringIO
    def self.absolute_path(filepath)
      RealFile.absolute_path(filepath)
    end
    def self.expand_path(filepath)
      RealFile.expand_path(filepath)
    end
  end
end
