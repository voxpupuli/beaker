require 'spec_helper'

EZBAKE_CONFIG_EXAMPLE= {
  :project => 'puppetserver',
  :real_name => 'puppetserver',
  :user => 'puppet',
  :group => 'puppet',
  :uberjar_name => 'puppetserver-release.jar',
  :config_files => [],
  :terminus_info => {},
  :debian => { :additional_dependencies => ["puppet (= 3.6.1-puppetlabs1)"], },
  :redhat => { :additional_dependencies => ["puppet = 3.6.1"], },
  :java_args => '-Xmx192m',
}

class ClassMixedWithEZBakeUtils
  include Beaker::DSL::EZBakeUtils

  def initialize_ezbake_config
    Beaker::DSL::EZBakeUtils.config = EZBAKE_CONFIG_EXAMPLE
  end

  def wipe_out_ezbake_config
    Beaker::DSL::EZBakeUtils.config = nil
  end

  def logger
    @logger ||= RSpec::Mocks::Double.new('logger').as_null_object
  end
end

module Beaker::DSL::EZBakeUtils::EZBake
  Config = EZBAKE_CONFIG_EXAMPLE
end

describe ClassMixedWithEZBakeUtils do
  let( :opts ) { Beaker::Options::Presets.env_vars }
  let( :host ) { double.as_null_object }
  let( :local_commands ) { Beaker::DSL::EZBakeUtils::LOCAL_COMMANDS_REQUIRED }

  describe '#install_from_ezbake' do
    let(:platform) { Beaker::Platform.new('el-7-i386') }
    let(:host) do
      FakeHost.create('fakevm', platform.to_s)
    end

    before do
      allow(subject).to receive(:ezbake_tools_available?) { true }
    end

    it "when ran with an el-7 machine runs correct installsh command" do
      expect(subject).to receive(:install_ezbake_tarball_on_host).
                          ordered
      expect(subject).
        to receive(:ezbake_installsh).with(host, "service")
      subject.install_from_ezbake host
    end
  end

  describe '#install_termini_from_ezbake' do
    let(:platform) { Beaker::Platform.new('el-7-i386') }
    let(:host) do
      FakeHost.create('fakevm', platform.to_s)
    end

    before do
      allow(subject).to receive(:ezbake_tools_available?) { true }
    end

    it "when ran with an el-7 machine runs correct installsh command" do
      expect(subject).to receive(:ezbake_validate_support).with(host).ordered
      expect(subject).to receive(:install_ezbake_tarball_on_host).
                          with(host).ordered
      expect(subject).
        to receive(:ezbake_installsh).with(host, "termini")
      subject.install_termini_from_ezbake host
    end
  end

  describe '#ezbake_validate_support' do
    context 'when OS supported' do
      let(:platform) { Beaker::Platform.new('el-7-i386') }
      let(:host) do
        FakeHost.create('fakevm', platform.to_s)
      end

      it 'should do nothing' do
        subject.ezbake_validate_support host
      end
    end

    context 'when OS not supported' do
      let(:platform) { Beaker::Platform.new('aix-12-ppc') }
      let(:host) do
        FakeHost.create('fakevm', platform.to_s)
      end

      it 'should throw exception' do
        expect {
          subject.ezbake_validate_support host
        }.to raise_error(RuntimeError,
                         "No support for aix within ezbake_utils ...")
      end
    end
  end

  def install_ezbake_tarball_on_host_common_expects
    result = object_double(Beaker::Result.new(host, "foo"), :exit_code => 1)
    expect(subject).to receive(:on).
                        with(kind_of(Beaker::Host), /test -d/,
                             anything()).ordered { result }
    expect(Dir).to receive(:chdir).and_yield()
    expect(subject).to receive(:ezbake_local_cmd).with(/rake package:tar/).ordered
    expect(subject).to receive(:scp_to).
                        with(kind_of(Beaker::Host), anything(), anything()).ordered
    expect(subject).to receive(:on).
                        with(kind_of(Beaker::Host), /tar -xzf/).ordered
    expect(subject).to receive(:on).
                        with(kind_of(Beaker::Host), /test -d/).ordered
  end

  describe '#install_ezbake_tarball_on_host' do
    let(:platform) { Beaker::Platform.new('el-7-i386') }
    let(:host) do
      FakeHost.create('fakevm', platform.to_s)
    end

    it 'when invoked with configuration should run expected tasks' do
      subject.initialize_ezbake_config
      install_ezbake_tarball_on_host_common_expects
      subject.install_ezbake_tarball_on_host host
    end

    it 'when invoked with nil configuration runs ezbake_stage' do
      subject.wipe_out_ezbake_config
      expect(subject).to receive(:ezbake_stage) {
        Beaker::DSL::EZBakeUtils.config = EZBAKE_CONFIG_EXAMPLE
      }.ordered
      install_ezbake_tarball_on_host_common_expects
      subject.install_ezbake_tarball_on_host host
    end
  end

  describe '#ezbake_tools_available?' do
    before do
      allow(subject).to receive(:check_for_package) { true }
      allow(subject).to receive(:system) { true }
    end

    describe "checks for local successful commands" do

      it "and succeeds if all commands return successfully" do
        local_commands.each do |software_name, command, additional_error_messages|
          expect(subject).to receive(:system).with(/#{command}/)
        end
        subject.ezbake_tools_available?
      end

      it "and raises an exception if a command returns failure" do
        allow(subject).to receive(:system) { false }
        local_commands.each do |software_name, command, additional_error_messages|
          expect(subject).to receive(:system).with(/#{command}/)
          break # just need first element
        end
        expect{
          subject.ezbake_tools_available?
        }.to raise_error(RuntimeError, /Must have .* installed on development system./)
      end

    end

  end

  describe '#ezbake_config' do
    it "returns a map with ezbake configuration parameters" do
      subject.initialize_ezbake_config
      config = subject.ezbake_config
      expect(config).to include(EZBAKE_CONFIG_EXAMPLE)
    end
  end

  describe '#ezbake_stage' do
    before do
      allow(subject).to receive(:ezbake_tools_available?) { true }
      subject.wipe_out_ezbake_config
    end

    it "initializes EZBakeUtils.config" do
      allow(Dir).to receive(:chdir).and_yield()

      expect(subject).to receive(:ezbake_local_cmd).
                          with(/^lein.*install/, :throw_on_failure =>
                                                 true).ordered
      expect(subject).to receive(:ezbake_local_cmd).
                          with(/^lein.*with-profile ezbake ezbake stage/, :throw_on_failure =>
                                                 true).ordered
      expect(subject).to receive(:ezbake_local_cmd).with("rake package:bootstrap").ordered
      expect(subject).to receive(:load) { }.ordered
      expect(subject).to receive(:`).ordered

      config = subject.ezbake_config
      expect(config).to eq(nil)

      subject.ezbake_stage

      config = subject.ezbake_config
      expect(config).to include(EZBAKE_CONFIG_EXAMPLE)
    end
  end

  describe '#ezbake_local_cmd' do
    it 'should execute system on the command specified' do
      expect(subject).to receive(:system).with("my command") { true }
      subject.ezbake_local_cmd("my command")
    end

    it 'with :throw_on_failure should throw exeception when failed' do
      expect(subject).to receive(:system).with("my failure") { false }
      expect {
        subject.ezbake_local_cmd("my failure", :throw_on_failure => true)
      }.to raise_error(RuntimeError, "Command failure my failure")
    end

    it 'without :throw_on_failure should just fail and return false' do
      expect(subject).to receive(:system).with("my failure") { false }
      expect(subject.ezbake_local_cmd("my failure")).to eq(false)
    end
  end

  describe '#ezbake_install_name' do
    it 'should return the installation name from example configuration' do
      expect(subject).to receive(:ezbake_config) {{
        :package_version => '1.1.1',
        :project => 'myproject',
      }}
      expect(subject.ezbake_install_name).to eq "myproject-1.1.1"
    end
  end

  describe '#ezbake_install_dir' do
    it 'should return the full path from ezbake_install_name' do
      expect(subject).to receive(:ezbake_install_name) {
        "mynewproject-2.3.4"
      }
      expect(subject.ezbake_install_dir).to eq "/root/mynewproject-2.3.4"
    end
  end

  describe '#ezbake_installsh' do
    it 'run on command correctly when invoked' do
      expect(subject).to receive(:on).with(host,
                                           /install.sh my_task/)
      subject.ezbake_installsh host, "my_task"
    end
  end

  describe '#conditionally_clone' do
    it 'when repo exists, just do fetch and checkout' do
      expect(subject).to receive(:ezbake_local_cmd).
        with(/git status/) { true }
      expect(subject).to receive(:ezbake_local_cmd).
        with(/git fetch origin/)
      expect(subject).to receive(:ezbake_local_cmd).
        with(/git checkout/)
      subject.conditionally_clone("my_url", "my_local_path")
    end

    it 'when repo does not exist, do clone and checkout' do
      expect(subject).to receive(:ezbake_local_cmd).
                          with(/git status/) { false }
      expect(subject).to receive(:ezbake_local_cmd).
                          with(/git clone/)
      expect(subject).to receive(:ezbake_local_cmd).
                          with(/git checkout/)
      subject.conditionally_clone("my_url", "my_local_path")
    end
  end

end
