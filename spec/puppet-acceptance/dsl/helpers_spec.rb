require 'spec_helper'

class ClassMixedWithDSLHelpers
  include PuppetAcceptance::DSL::Helpers
end

describe ClassMixedWithDSLHelpers do
  describe '#on' do
    it 'allows the environment the command is run within to be specified' do
      host = double.as_null_object

      PuppetAcceptance::Command.should_receive( :new ).
        with( 'ls ~/.bin', [], {'ENV' => { :HOME => '/tmp/test_home' }} )

      subject.on( host, 'ls ~/.bin', :environment => {:HOME => '/tmp/test_home' } )
    end

    it 'delegates to itself for each host passed' do
      hosts = [ double, double, double ]

      hosts.each_with_index do |host, i|
        host.should_receive( :exec ).and_return( i )
      end

      results = subject.on( hosts, 'ls' )
      expect( results ).to be == [ 0, 1, 2 ]
    end

    it 'yields to a given block' do
      host = double.as_null_object

      subject.on host, 'ls' do |containing_class|
        expect( containing_class ).
          to be_an_instance_of( ClassMixedWithDSLHelpers )
      end
    end

    it 'returns the result of the action' do
      host = double.as_null_object

      host.should_receive( :exec ).and_return( 'my_result' )

      expect( subject.on( host, 'ls' ) ).to be == 'my_result'
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
end
