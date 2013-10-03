require 'spec_helper'

class ClassMixedWithDSLHelpers
  include Beaker::DSL::Helpers
  include Beaker::DSL::Wrappers

  def logger
    @logger ||= RSpec::Mocks::Mock.new('logger').as_null_object
  end
end

describe ClassMixedWithDSLHelpers do

  describe '#on' do
    let( :command )  { 'ls' }
    let( :hosts ) { [ double, double, double ] }
    let( :host ) { double.as_null_object }
    let( :result ) { Beaker::Result.new( host, command ) }

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

    it 'delegates to itself for each host passed' do

      hosts.each_with_index do |host, i|
        host.should_receive( :exec ).and_return( i )
      end

      results = subject.on( hosts, command )
      expect( results ).to be == [ 0, 1, 2 ]
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

      it 'yields self' do
        subject.on host, command do |containing_class|
          expect( containing_class ).
            to be_an_instance_of( ClassMixedWithDSLHelpers )
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

  describe '#scp_from' do
    it 'delegates to the host' do
      hosts = [ double, double, double ]
      result = double

      subject.should_receive( :logger ).exactly( 3 ).times
      result.should_receive( :log ).exactly( 3 ).times
      hosts.each do |host|
        host.should_receive( :do_scp_from ).and_return( result )
      end

      subject.scp_from( hosts, '/var/log/my.log', 'log/my.log' )
    end
  end

  describe '#scp_to' do
    it 'delegates to the host' do
      hosts = [ double, double, double ]
      result = double

      subject.should_receive( :logger ).exactly( 3 ).times
      result.should_receive( :log ).exactly( 3 ).times
      hosts.each do |host|
        host.should_receive( :do_scp_to ).and_return( result )
      end

      subject.scp_to( hosts, '/var/log/my.log', 'log/my.log' )
    end
  end

  describe '#create_remote_file' do
    it 'scps the contents passed in to the hosts' do
      hosts = [ 'uno.example.org', 'dos.example.org' ]
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

    #let(:host_param)    { @host_param || Array.new }
    #let(:logger_param)  { double('logger').as_null_object }
    #let(:config_param)  { Hash.new }
    #let(:options_param) { Hash.new }
    #let(:path_param)    { '/file/path/string' }
    #let(:test_case) do
    #  TestCase.new( host_param, logger_param, config_param, options_param, path_param )
    #end

    describe 'confine' do
      let(:logger) { double.as_null_object }
      before do
        subject.should_receive( :logger ).any_number_of_times.and_return( logger )
      end

      it 'skips the test if there are no applicable hosts' do
        subject.should_receive( :hosts ).any_number_of_times.and_return( [] )
        subject.should_receive( :hosts= ).any_number_of_times
        logger.should_receive( :warn )
        subject.should_receive( :skip_test ).
          with( 'No suitable hosts found' )

        subject.confine( :to, {} )
      end

      it 'raises when given mode is not :to or :except' do
        subject.should_receive( :hosts ).any_number_of_times
        subject.should_receive( :hosts= ).any_number_of_times

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
    it 'allows acceptable exit codes through :catch_failures' do
      subject.should_receive( :puppet ).
        with( 'apply', '--verbose', '--trace', '--detailed-exitcodes' ).
        and_return( 'puppet_command' )

      subject.should_receive( :on ).
        with( 'my_host', 'puppet_command',
              :acceptable_exit_codes => [4,0,2],
              :stdin => "class { \"boo\": }\n" )

      subject.apply_manifest_on( 'my_host',
                                'class { "boo": }',
                                :acceptable_exit_codes => [4],
                                :trace => true,
                                :catch_failures => true )
    end
  end

  describe '#stub_hosts_on' do
    it 'executes puppet on the host passed and ensures it is reverted' do
      logger = double.as_null_object

      subject.should_receive( :logger ).any_number_of_times.and_return( logger )
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

  describe '#stub_forge_on' do
    it 'stubs forge.puppetlabs.com with the value of `forge`' do
      subject.should_receive( :forge ).and_return( 'my_forge.example.com' )
      Resolv.should_receive( :getaddress ).
        with( 'my_forge.example.com' ).and_return( '127.0.0.1' )
      subject.should_receive( :stub_hosts_on ).
        with( 'my_host', 'forge.puppetlabs.com' => '127.0.0.1' )

      subject.stub_forge_on( 'my_host' )
    end
  end

  describe '#with_puppet_running_on' do
    let(:is_pe) { false }
    let(:host) { FakeHost.new(:pe => is_pe) }
    let(:test_case_path) { 'testcase/path' }
    let(:tmpdir_path) { '/tmp/tmpdir' }
    let(:puppet_path) { '/puppet/path' }

    def stub_host_and_subject_to_allow_the_default_testdir_argument_to_be_created
      subject.instance_variable_set(:@path, test_case_path)
      host.stub(:tmpdir).and_return(tmpdir_path)
    end

    before do
      stub_host_and_subject_to_allow_the_default_testdir_argument_to_be_created
      host.stub(:[]).and_return(puppet_path)
    end

    it "raises an ArgumentError if you try to submit a String instead of a Hash of options" do
      expect { subject.with_puppet_running_on(host, '--foo --bar') }.to raise_error(ArgumentError, /conf_opts must be a Hash. You provided a String: '--foo --bar'/)
    end

    describe "with valid arguments" do
      before do
        Tempfile.should_receive(:open).with('beaker')
      end

      context 'as pe' do
        let(:is_pe) { true }

        it 'bounces puppet twice' do
          subject.with_puppet_running_on(host, {})
          expect(host).to execute_commands_matching(/pe-httpd restart/).exactly(2).times
        end

        it 'yield to a block after bouncing service' do
          execution = 0
          expect do
            subject.with_puppet_running_on(host, {}) do
              expect(host).to execute_commands_matching(/pe-httpd restart/).once
              execution += 1
            end
          end.to change { execution }.by(1)
          expect(host).to execute_commands_matching(/pe-httpd restart/).exactly(2).times
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
          expect(host).to execute_commands_matching(/cat #{backup_location} > #{original_location}/).once
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
end
