require 'spec_helper'

class ClassMixedWithDSLInstallUtils
  include Beaker::DSL::Helpers
  include Beaker::DSL::Patterns
  include Beaker::DSL::InstallUtils

  def logger
    @logger ||= RSpec::Mocks::Double.new('logger').as_null_object
  end
end

describe ClassMixedWithDSLInstallUtils do
  let(:windows_temp)        { 'C:\\Windows\\Temp' }
  let( :batch_path )        { '/fake/batch/path' }
  let(:msi_path)            { 'c:\\foo\\puppet.msi' }
  let(:winhost)             { make_host( 'winhost',
                            { :platform => Beaker::Platform.new('windows-2008r2-64'),
                                :pe_ver => '3.0',
                                :working_dir => '/tmp',
                                :is_cygwin => true} ) }
  let(:winhost_non_cygwin)  { make_host( 'winhost_non_cygwin',
                              { :platform => 'windows',
                                :pe_ver => '3.0',
                                :working_dir => '/tmp',
                                :is_cygwin => 'false' } ) }
  let(:hosts)              { [ winhost, winhost_non_cygwin ] }

  def expect_install_called(times = hosts.length)
    result = expect( Beaker::Command ).to receive( :new )
      .with( /^"#{batch_path}"$/, [], {:cmdexe => true})
      .exactly( times ).times

    yield result if block_given?
  end

  def expect_status_called(times = hosts.length)
    expect( Beaker::Command ).to receive( :new )
      .with( "sc qc puppet || sc qc pe-puppet", [], {:cmdexe => true} )
      .exactly( times ).times
  end

  def expect_version_log_called(times = hosts.length)
    [
      "\\\"%ProgramFiles%\\Puppet Labs\\puppet\\misc\\versions.txt\\\"",
      "\\\"%ProgramFiles(x86)%\\Puppet Labs\\puppet\\misc\\versions.txt\\\"",
    ].each do |path|
      expect( Beaker::Command ).to receive( :new )
        .with( "\"if exist #{path} type #{path}\"", [], {:cmdexe => true} )
        .exactly( times ).times
    end
  end

  def expect_script_matches(hosts, contents)
    hosts.each do |host|
      expect( host )
        .to receive( :do_scp_to ) do |local_path, remote_path|
          expect(File.read(local_path)).to match(contents)
        end
        .and_return( true )
    end
  end

  def expect_reg_query_called(times = hosts.length)
    hosts.each do |host|
      expect(host).to receive(:is_x86_64?).and_return(:true)
    end

    expect( Beaker::Command ).to receive( :new )
      .with(%r{reg query "HKLM\\SOFTWARE\\Wow6432Node\\Puppet Labs\\PuppetInstaller}, [], {:cmdexe => true})
      .exactly(times).times
  end

  describe "#install_msi_on" do
    let( :log_file )    { '/fake/log/file.log' }
    before :each do
      allow( subject ).to receive( :on ).and_return( true )
      allow( subject ).to receive( :create_install_msi_batch_on ).and_return( [batch_path, log_file] )
    end

    it "will specify a PUPPET_AGENT_STARTUP_MODE of Manual (disabling the service) by default" do
      expect_install_called
      expect_status_called
      expect_reg_query_called
      expect_version_log_called
      expect( subject ).to receive( :create_install_msi_batch_on ).with(
          anything, anything,
          'PUPPET_AGENT_STARTUP_MODE' => 'Manual')
      subject.install_msi_on(hosts, msi_path, {})
    end

    it "allows configuration of PUPPET_AGENT_STARTUP_MODE" do
      expect_install_called
      expect_status_called
      expect_reg_query_called
      expect_version_log_called
      value = 'Automatic'
      expect( subject ).to receive( :create_install_msi_batch_on ).with(
          anything, anything,
          'PUPPET_AGENT_STARTUP_MODE' => value)
      subject.install_msi_on(hosts, msi_path, {'PUPPET_AGENT_STARTUP_MODE' => value})
    end

    it "will not generate a command to emit a log file without the :debug option set" do
      expect_install_called
      expect_status_called
      expect( Beaker::Command ).not_to receive( :new ).with( /^type .*\.log$/, [], {:cmdexe => true} )
      subject.install_msi_on(hosts, msi_path)
    end

    it "will generate a command to emit a log file when the install script fails" do
      # note a single failure aborts executing against remaining hosts
      hosts_affected = 1

      expect_install_called(hosts_affected) { |e| e.and_raise }
      expect_status_called(0)

      expect( Beaker::Command ).to receive( :new ).with( /^type \".*\.log\"$/, [], {:cmdexe => true} ).exactly( hosts_affected ).times
      expect { subject.install_msi_on(hosts, msi_path) }.to raise_error(RuntimeError)
    end

    it "will generate a command to emit a log file with the :debug option set" do
      expect_install_called
      expect_reg_query_called
      expect_status_called
      expect_version_log_called

      expect( Beaker::Command ).to receive( :new ).with( /^type \".*\.log\"$/, [], {:cmdexe => true} ).exactly( hosts.length ).times
      subject.install_msi_on(hosts, msi_path, {}, { :debug => true })
    end

    it 'will pass msi_path to #create_install_msi_batch_on as-is' do
      expect_install_called
      expect_reg_query_called
      expect_status_called
      expect_version_log_called
      test_path = 'test/path'
      expect( subject ).to receive( :create_install_msi_batch_on ).with(
          anything, test_path, anything)
      subject.install_msi_on(hosts, test_path)
    end

    it 'will search in Wow6432Node for the remembered startup setting on 64-bit hosts' do
      expect_install_called
      expect_status_called
      expect_version_log_called

      hosts.each do |host|
        expect(host).to receive(:is_x86_64?).and_return(true)
      end

      expect( Beaker::Command ).to receive( :new )
        .with('reg query "HKLM\\SOFTWARE\\Wow6432Node\\Puppet Labs\\PuppetInstaller" /v "RememberedPuppetAgentStartupMode" | findstr Foo', [], {:cmdexe => true})
        .exactly(hosts.length).times

      subject.install_msi_on(hosts, msi_path, {'PUPPET_AGENT_STARTUP_MODE' => "Foo"})
    end

    it 'will omit Wow6432Node in the registry search for remembered startup setting on 32-bit hosts' do
      expect_install_called
      expect_status_called
      expect_version_log_called

      hosts.each do |host|
        expect(host).to receive(:is_x86_64?).and_return(false)
      end

      expect( Beaker::Command ).to receive( :new )
        .with('reg query "HKLM\\SOFTWARE\\Puppet Labs\\PuppetInstaller" /v "RememberedPuppetAgentStartupMode" | findstr Foo', [], {:cmdexe => true})
        .exactly(hosts.length).times

      subject.install_msi_on(hosts, msi_path, {'PUPPET_AGENT_STARTUP_MODE' => "Foo"})
    end
  end

  describe '#create_install_msi_batch_on' do
    let( :tmp         ) { '/tmp/create_install_msi_batch_on' }
    let( :tmp_slashes ) { tmp.gsub('/', '\\') }

    before :each do
      FakeFS::FileSystem.add(File.expand_path tmp)
      hosts.each do |host|
        allow( host ).to receive( :system_temp_path ).and_return( tmp )
      end
    end

    it 'passes msi_path & msi_opts down to #msi_install_script' do
      allow( winhost ).to receive( :do_scp_to )
      test_path = '/path/to/test/with/13540'
      test_opts = { 'key1' => 'val1', 'key2' => 'val2' }
      expect( subject ).to receive( :msi_install_script ).with(
        test_path, test_opts, anything )
      subject.create_install_msi_batch_on(winhost, test_path, test_opts)
    end

    it 'SCPs to & returns the same batch file path, corrected for slashes' do
      test_time = Time.now
      allow( Time ).to receive( :new ).and_return( test_time )
      timestamp = test_time.strftime('%Y-%m-%d_%H.%M.%S')

      correct_path = "#{tmp_slashes}\\install-puppet-msi-#{timestamp}.bat"
      expect( winhost ).to receive( :do_scp_to ).with( anything, correct_path, {} )
      test_path, _ = subject.create_install_msi_batch_on( winhost, msi_path, {} )
      expect( test_path ).to be === correct_path
    end

    it 'returns & sends log_path to #msi_install_scripts, corrected for slashes' do
      allow( winhost ).to receive( :do_scp_to )
      test_time = Time.now
      allow( Time ).to receive( :new ).and_return( test_time )
      timestamp = test_time.strftime('%Y-%m-%d_%H.%M.%S')

      correct_path = "#{tmp_slashes}\\install-puppet-#{timestamp}.log"
      expect( subject ).to receive( :msi_install_script ).with(
          anything, anything, correct_path )
      _, log_path = subject.create_install_msi_batch_on( winhost, msi_path, {} )
      expect( log_path ).to be === correct_path
    end
  end

  describe '#msi_install_script' do
    let( :log_path ) { '/log/msi_install_script' }

    context 'msi_params parameter' do
      it 'can take an empty hash' do
        expected_cmd = /^start \/w msiexec\.exe \/i ".*" \/qn \/L\*V #{log_path}\ .exit/m
        expect( subject.msi_install_script(msi_path, {}, log_path) ).to match(expected_cmd)
      end

      it 'uses a key-value pair correctly' do
        params = { 'tk1' => 'tv1' }
        expected_cmd = /^start \/w msiexec\.exe \/i ".*" \/qn \/L\*V #{log_path}\ tk1\=tv1/
        expect( subject.msi_install_script(msi_path, params, log_path) ).to match(expected_cmd)
      end

      it 'uses multiple key-value pairs correctly' do
        params = { 'tk1' => 'tv1', 'tk2' => 'tv2' }
        expected_cmd = /^start \/w msiexec\.exe \/i ".*" \/qn \/L\*V #{log_path}\ tk1\=tv1\ tk2\=tv2/
        expect( subject.msi_install_script(msi_path, params, log_path) ).to match(expected_cmd)
      end
    end

    context 'msi_path parameter' do
      it "will generate an appropriate command with a MSI file path using non-Windows slashes" do
        msi_path = 'c:/foo/puppet.msi'
        expected_cmd = /^start \/w msiexec\.exe \/i "c:\\foo\\puppet.msi" \/qn \/L\*V #{log_path}/
        expect( subject.msi_install_script(msi_path, {}, log_path) ).to match(expected_cmd)
      end

      it "will generate an appropriate command with a MSI http(s) url" do
        msi_url = "https://downloads.puppetlabs.com/puppet.msi"
        expected_cmd = /^start \/w msiexec\.exe \/i "https\:\/\/downloads\.puppetlabs\.com\/puppet\.msi" \/qn \/L\*V #{log_path}/
        expect( subject.msi_install_script(msi_url, {}, log_path) ).to match(expected_cmd)
      end

      it "will generate an appropriate command with a MSI file url" do
        msi_url = "file://c:\\foo\\puppet.msi"
        expected_cmd = /^start \/w msiexec\.exe \/i "file\:\/\/c:\\foo\\puppet\.msi" \/qn \/L\*V #{log_path}/
        expect( subject.msi_install_script(msi_url, {}, log_path) ).to match(expected_cmd)
      end
    end
  end
end
