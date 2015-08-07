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
  let(:msi_path)            { 'c:\\foo\\puppet.msi' }
  let(:winhost)             { make_host( 'winhost',
                              { :platform => 'windows',
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
      .with( /^"#{Regexp.quote(windows_temp)}\\install-puppet-msi.*\.bat"$/, [], {:cmdexe => true})
      .exactly( times ).times

    yield result if block_given?
  end

  def expect_status_called(times = hosts.length)
    expect( Beaker::Command ).to receive( :new )
      .with( "sc query puppet || sc query pe-puppet", [], {:cmdexe => true} )
      .exactly( times ).times
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

  describe "#install_msi_on" do
    before :each do
      FakeFS::FileSystem.add(File.expand_path '/tmp')

      allow( subject ).to receive( :on ).and_return( true )
      allow( subject ).to receive( :get_temp_path ).and_return( windows_temp )
    end

    it "will specify a PUPPET_AGENT_STARTUP_MODE of Manual (disabling the service) by default" do
      expect_install_called
      expect_status_called
      expected_cmd = /^start \/w msiexec\.exe \/i "c:\\foo\\puppet.msi" \/qn \/L\*V .*\.log PUPPET_AGENT_STARTUP_MODE=Manual$/
      expect_script_matches(hosts, expected_cmd)
      subject.install_msi_on(hosts, msi_path, {})
    end

    it "allows configuration of PUPPET_AGENT_STARTUP_MODE" do
      expect_install_called
      expect_status_called
      expected_cmd = /^start \/w msiexec\.exe \/i "c:\\foo\\puppet.msi" \/qn \/L\*V .*\.log PUPPET_AGENT_STARTUP_MODE=Automatic$/
      expect_script_matches(hosts, expected_cmd)
      subject.install_msi_on(hosts, msi_path, {'PUPPET_AGENT_STARTUP_MODE' => 'Automatic'})
    end

    it "will generate an appropriate command with a MSI file path using non-Windows slashes" do
      expect_install_called
      expect_status_called
      msi_path = 'c:/foo/puppet.msi'
      expected_cmd = /^start \/w msiexec\.exe \/i "c:\\foo\\puppet.msi" \/qn \/L\*V .*\.log PUPPET_AGENT_STARTUP_MODE=Manual$/
      expect_script_matches(hosts, expected_cmd)
      subject.install_msi_on(hosts, msi_path)
    end

    it "will generate an appropriate command with a MSI http(s) url" do
      expect_install_called
      expect_status_called
      msi_url = "https://downloads.puppetlabs.com/puppet.msi"
      expected_cmd = /^start \/w msiexec\.exe \/i "https\:\/\/downloads\.puppetlabs\.com\/puppet\.msi" \/qn \/L\*V .*\.log PUPPET_AGENT_STARTUP_MODE=Manual$/
      expect_script_matches(hosts, expected_cmd)
      subject.install_msi_on(hosts, msi_url)
    end

    it "will generate an appropriate command with a MSI file url" do
      expect_install_called
      expect_status_called
      msi_url = "file://c:\\foo\\puppet.msi"
      expected_cmd = /^start \/w msiexec\.exe \/i "file\:\/\/c:\\foo\\puppet\.msi" \/qn \/L\*V .*\.log PUPPET_AGENT_STARTUP_MODE=Manual$/
      expect_script_matches(hosts, expected_cmd)
      subject.install_msi_on(hosts, msi_url)
    end

    it "will not generate a command to emit a log file without the :debug option set" do
      expect_install_called
      expect_status_called
      hosts.each { |h| allow( h ).to receive( :do_scp_to ).and_return( true ) }
      expect( Beaker::Command ).not_to receive( :new ).with( /^type .*\.log$/, [], {:cmdexe => true} )
      subject.install_msi_on(hosts, msi_path)
    end

    it "will generate a command to emit a log file when the install script fails" do
      # note a single failure aborts executing against remaining hosts
      hosts_affected = 1

      expect_install_called(hosts_affected) { |e| e.and_raise }
      expect_status_called(0)
      hosts.each { |h| allow( h ).to receive( :do_scp_to ).and_return( true ) }

      expect( Beaker::Command ).to receive( :new ).with( /^type \".*\.log\"$/, [], {:cmdexe => true} ).exactly( hosts_affected ).times
      expect { subject.install_msi_on(hosts, msi_path) }.to raise_error(RuntimeError)
    end

    it "will generate a command to emit a log file with the :debug option set" do
      expect_install_called
      expect_status_called
      hosts.each { |h| allow( h ).to receive( :do_scp_to ).and_return( true ) }

      expect( Beaker::Command ).to receive( :new ).with( /^type \".*\.log\"$/, [], {:cmdexe => true} ).exactly( hosts.length ).times
      subject.install_msi_on(hosts, msi_path, {}, { :debug => true })
    end
  end
end
