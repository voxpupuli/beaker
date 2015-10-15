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
            expect(subject).to receive(:create_tmpdir_on).with(host, /\/tmp\/beaker/, /puppet/)
            subject.create_tmpdir_for_user(host)
          end
        end
      end

      context 'with path name argument' do
        it 'executes chown once' do
          cmd = "the command"
          expect(Beaker::Command).to receive(:new).with(/puppet master --configprint user/, [], {"ENV"=>{}, :cmdexe=>true}).and_return(cmd)
          expect(subject).to receive(:on).with(host, cmd).and_return(result)
          expect(subject).to receive(:create_tmpdir_on).with(host, /\/tmp\/bogus/, /puppet/)
          subject.create_tmpdir_for_user(host, "/tmp/bogus")
        end
      end

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

  describe "#stop_agent_on" do
    let( :result_fail ) { Beaker::Result.new( [], "" ) }
    let( :result_pass ) { Beaker::Result.new( [], "" ) }
    before :each do
      allow( subject ).to receive( :sleep ).and_return( true )
    end

    it 'runs the pe-puppet on a system without pe-puppet-agent' do
      vardir = '/var'
      deb_agent = make_host( 'deb', :platform => 'debian-7-amd64', :pe_ver => '3.7' )
      allow( deb_agent ).to receive( :puppet ).and_return( { 'vardir' => vardir } )

      expect( deb_agent ).to receive( :file_exist? ).with("/var/state/agent_catalog_run.lock").and_return(false)
      expect( deb_agent ).to receive( :file_exist? ).with("/etc/init.d/pe-puppet-agent").and_return(false)

      expect( subject ).to receive( :puppet_resource ).with( "service", "pe-puppet", "ensure=stopped").once
      expect( subject ).to receive( :on ).once

      subject.stop_agent_on( deb_agent )

    end

    it 'runs the pe-puppet-agent on a unix system with pe-puppet-agent' do
      vardir = '/var'
      el_agent = make_host( 'el', :platform => 'el-5-x86_64', :pe_ver => '3.7' )
      allow( el_agent ).to receive( :puppet ).and_return( { 'vardir' => vardir } )

      expect( el_agent ).to receive( :file_exist? ).with("/var/state/agent_catalog_run.lock").and_return(false)
      expect( el_agent ).to receive( :file_exist? ).with("/etc/init.d/pe-puppet-agent").and_return(true)

      expect( subject ).to receive( :puppet_resource ).with( "service", "pe-puppet-agent", "ensure=stopped").once
      expect( subject ).to receive( :on ).once

      subject.stop_agent_on( el_agent )
    end

    it 'runs puppet on a unix system 4.0 or newer' do
      vardir = '/var'
      el_agent = make_host( 'el', :platform => 'el-5-x86_64', :pe_ver => '4.0' )
      allow( el_agent ).to receive( :puppet ).and_return( { 'vardir' => vardir } )

      expect( el_agent ).to receive( :file_exist? ).with("/var/state/agent_catalog_run.lock").and_return(false)

      expect( subject ).to receive( :puppet_resource ).with( "service", "puppet", "ensure=stopped").once
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

    it 'receives a Minitest::Assertion and fails the test correctly' do
      allow( subject ).to receive( :backup_the_file ).and_raise( Minitest::Assertion.new('assertion failed!') )
      expect( subject ).to receive( :fail_test )
      subject.with_puppet_running_on(host, {})
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
        allow( host ).to receive(:puppet).with( any_args ).and_return({
          'confdir' => default_confdir,
          'vardir' => default_vardir,
          'config' => "#{default_confdir}/puppet.conf"
        })
      end

      describe 'and command line args passed' do
        it 'modifies SUT trapperkeeper configuration w/ command line args' do
          host['puppetserver-confdir'] = '/etc/puppetserver/conf.d'
          expect( subject ).to receive( :modify_tk_config).with(host, puppetserver_conf,
                                                          custom_puppetserver_opts)
          subject.with_puppet_running_on(host, conf_opts)
        end
      end

      describe 'and no command line args passed' do
        let(:command_line_args) { nil }
        it 'modifies SUT trapperkeeper configuration w/ puppet defaults' do
          host['puppetserver-confdir'] = '/etc/puppetserver/conf.d'
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

        it 'yields to a block in between bouncing service calls' do
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

        context ':restart_when_done flag set false' do
          it 'starts puppet once, stops it twice' do
            subject.with_puppet_running_on(host, { :restart_when_done => false })
            expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=running/).once
            expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=stopped/).exactly(2).times
          end

          it 'can be set globally in options' do
            host[:restart_when_done] = false

            subject.with_puppet_running_on(host, {})

            expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=running/).once
            expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=stopped/).exactly(2).times
          end

          it 'yields to a block after bouncing service' do
            execution = 0
            allow( subject ).to receive(:curl_with_retries)
            expect do
              subject.with_puppet_running_on(host, { :restart_when_done => false }) do
                expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=running/).exactly(1).times
                expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=stopped/).exactly(1).times
                execution += 1
              end
            end.to change { execution }.by(1)
            expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=stopped/).exactly(2).times
          end
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

        context ':restart_when_done flag set false' do
          it 'bounces puppet once' do
            allow( subject ).to receive(:curl_with_retries)
            subject.with_puppet_running_on(host, { :restart_when_done => false })
            expect(host).to execute_commands_matching(/apache2ctl graceful/).once
          end

          it 'yields to a block after bouncing service' do
            execution = 0
            allow( subject ).to receive(:curl_with_retries)
            expect do
              subject.with_puppet_running_on(host, { :restart_when_done => false }) do
                expect(host).to execute_commands_matching(/apache2ctl graceful/).once
                execution += 1
              end
            end.to change { execution }.by(1)
          end
        end
      end

      context 'for foss packaged hosts using webrick' do
        let(:use_service) { true }

        it 'stops and starts master using service scripts twice' do
          allow( subject ).to receive(:curl_with_retries)
          subject.with_puppet_running_on(host, {})
          expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=running/).exactly(2).times
          expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=stopped/).exactly(2).times
        end

        it 'yields to a block in between bounce calls for the service' do
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

        context ':restart_when_done flag set false' do
          it 'stops (twice) and starts (once) master using service scripts' do
            allow( subject ).to receive(:curl_with_retries)
            subject.with_puppet_running_on(host, { :restart_when_done => false })
            expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=running/).once
            expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=stopped/).exactly(2).times
          end

          it 'yields to a block after stopping and starting service' do
            execution = 0
            expect do
              subject.with_puppet_running_on(host, { :restart_when_done => false }) do
                expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=running/).once
                expect(host).to execute_commands_matching(/puppet resource service #{host['puppetservice']}.*ensure=stopped/).once
                execution += 1
              end
            end.to change { execution }.by(1)
          end
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
                expect(host).to execute_commands_matching(/^puppet master/).exactly(4).times
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

          it 'is not affected by the :restart_when_done flag' do
            execution = 0
            expect do
              subject.with_puppet_running_on(host, { :restart_when_done => true }) do
                expect(host).to execute_commands_matching(/^puppet master/).exactly(4).times
                execution += 1
              end
            end.to change { execution }.by(1)
            expect(host).to execute_commands_matching(/^kill [^-]/).once
            expect(host).to execute_commands_matching(/^kill -0/).once
          end
        end
      end

      describe 'backup and restore of puppet.conf' do
        before :each do
          mock_puppetconf_reader = Object.new
          allow( mock_puppetconf_reader ).to receive( :[] ).with( 'config' ).and_return( '/root/mock/puppet.conf' )
          allow( mock_puppetconf_reader ).to receive( :[] ).with( 'confdir' ).and_return( '/root/mock' )
          allow( host ).to receive( :puppet ).with( any_args ).and_return( mock_puppetconf_reader )
        end

        let(:original_location) { host.puppet['config'] }
        let(:backup_location) {
          filename = File.basename(host.puppet['config'])
          File.join(tmpdir_path, "#{filename}.bak")
        }
        let(:new_location) {
          filename = File.basename(host.puppet['config'])
          File.join(tmpdir_path, filename)
        }

        context 'when a puppetservice is used' do
          let(:use_service) { true }

          it 'backs up puppet.conf' do
            subject.with_puppet_running_on(host, {})
            expect(host).to execute_commands_matching(/cp #{original_location} #{backup_location}/).once
            expect(host).to execute_commands_matching(/cat #{new_location} > #{original_location}/).once
          end

          it 'restores puppet.conf before restarting' do
            subject.with_puppet_running_on(host, { :restart_when_done => true })
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

      expect( subject ).to receive( :with_puppet_running_on ).with( master, {:opt => 'value'}, '/dir' ).once

      subject.with_puppet_running( {:opt => 'value'}, '/dir' )


    end
  end


end
