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
  let( :remote_packages ) { Beaker::DSL::EZBakeUtils::REMOTE_PACKAGES_REQUIRED }

  describe '#install_from_ezbake' do
    let(:platform) { Beaker::Platform.new('el-7-i386') }
    let(:host) do
      FakeHost.create('fakevm', platform.to_s)
    end

    it 'when no project name provided should retrieve project name' do
      expect(subject).to receive(:ezbake_lein_project_name).
                          ordered { "my project name" }
      expect(subject).to receive(:install_ezbake_tarball_on_host).
                          ordered
      expect(subject).
        to receive(:ezbake_make).with(host, "install-source-rpm-systemd",
                                      "defaultsdir" => "/etc/sysconfig")
      subject.install_from_ezbake host
    end

    it "when ran with an el-7 machine runs correct make command" do
      expect(subject).to receive(:install_ezbake_tarball_on_host).
                          ordered
      expect(subject).
        to receive(:ezbake_make).with(host, "install-source-rpm-systemd",
                                      "defaultsdir" => "/etc/sysconfig")
      subject.install_from_ezbake host, "blah", "blah"
    end
  end

  describe '#install_termini_from_ezbake' do
    let(:platform) { Beaker::Platform.new('el-7-i386') }
    let(:host) do
      FakeHost.create('fakevm', platform.to_s)
    end

    it 'when no project name provided should retrieve project name' do
      expect(subject).to receive(:ezbake_validate_support).with(host).ordered
      expect(subject).to receive(:ezbake_lein_project_name).
                          ordered { "myproject" }
      expect(subject).to receive(:install_ezbake_tarball_on_host).
                          with(host, "myproject", nil, anything()).
                          ordered
      expect(subject).
        to receive(:ezbake_make).with(host, "install-myproject-termini")
      subject.install_termini_from_ezbake host
    end

    it "when ran with an el-7 machine runs correct make command" do
      expect(subject).to receive(:ezbake_validate_support).with(host).ordered
      expect(subject).to receive(:install_ezbake_tarball_on_host).
                          with(host, "blah", "blah", anything()).
                          ordered
      expect(subject).
        to receive(:ezbake_make).with(host, "install-blah-termini")
      subject.install_termini_from_ezbake host, "blah", "blah"
    end
  end

  RSpec.shared_examples "installs-ezbake-dependencies" do
    it "installs ezbake dependencies" do
      expect(subject).to receive(:install_package).
        with( kind_of(Beaker::Host), anything(), anything())
      subject.install_ezbake_deps host
    end
  end

  describe '#install_ezbake_deps' do
    let(:platform) { Beaker::Platform.new('redhat-7-i386') }
    let(:host) do
      FakeHost.create('fakevm', platform.to_s)
    end

    before do
      allow(subject).to receive(:ezbake_tools_available?) { true }
      subject.initialize_ezbake_config
    end

    context "When host is a debian-like platform" do
      let(:platform) { Beaker::Platform.new('debian-7-i386') }
      include_examples "installs-ezbake-dependencies"
    end

    context "When host is a redhat-like platform" do
      let(:platform) { Beaker::Platform.new('centos-7-i386') }
      include_examples "installs-ezbake-dependencies"
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

  describe '#ezbake_lein_pprint' do
    it 'should run lein pprint and return result directly' do
      expect(subject).
        to receive(:`).with(/lein with-profile/) { "myvalue" }
      expect(subject.ezbake_lein_pprint ":foo").to eq "myvalue"
    end
    #` TODO stupid emacs problem
  end

  describe '#ezbake_lein_project_name' do
    it 'should call ezbake_lein_pprint' do
      expect(subject).
        to receive(:ezbake_lein_pprint).
            with(":name") { "myname" }
      expect(subject.ezbake_lein_project_name).to eq "myname"
    end
  end

  describe '#ezbake_lein_project_version' do
    it 'should call ezbake_lein_pprint' do
      expect(subject).
        to receive(:ezbake_lein_pprint).
            with(":version") { "myversion" }
      expect(subject.ezbake_lein_project_version).to eq "myversion"
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

    before do
      allow(subject).to receive(:ezbake_tools_available?) { true}
    end

    it 'when invoked with configuration should run expected tasks' do
      subject.initialize_ezbake_config
      install_ezbake_tarball_on_host_common_expects
      subject.install_ezbake_tarball_on_host host, "blah", "blah"
    end

    it 'when invoked with nil configuration runs ezbake_stage' do
      subject.wipe_out_ezbake_config
      expect(subject).to receive(:ezbake_stage) {
        Beaker::DSL::EZBakeUtils.config = EZBAKE_CONFIG_EXAMPLE
      }.ordered
      install_ezbake_tarball_on_host_common_expects
      subject.install_ezbake_tarball_on_host host, "blah", "blah"
    end
  end

  describe '#ezbake_tools_available?' do
    before do
      allow(subject).to receive(:check_for_package) { true }
      allow(subject).to receive(:system) { true }
    end

    describe "checks for remote packages when given a host" do

      it "and succeeds if all packages are found" do
        remote_packages.each do |package|
          expect(subject).to receive(:check_for_package).with(host, package)
        end
        subject.ezbake_tools_available? host
      end

      it "and raises an exception if a package is missing" do
        allow(subject).to receive(:check_for_package) { false }
        remote_packages.each do |package|
          expect(subject).to receive(:check_for_package).with(host, package)
          break # just need first element
        end
      expect{
        subject.ezbake_tools_available? host
      }.to raise_error(RuntimeError, /Required package, .*, not installed on/)
      end
    end

    describe "checks for local successful local commands when no host given" do

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
      allow(subject).to receive(:conditionally_clone) { true }

      expect(subject).to receive(:ezbake_local_cmd).
                          with(/^lein.*install/, :throw_on_failure =>
                                                 true).ordered
      expect(Dir).to receive(:chdir).and_yield().ordered
      expect(subject).to receive(:ezbake_local_cmd).
                          with(/^lein.*run -- stage/, :throw_on_failure =>
                                                 true).ordered
      expect(subject).to receive(:ezbake_local_cmd).with("rake package:bootstrap").ordered
      expect(subject).to receive(:load) { }.ordered
      expect(subject).to receive(:`).ordered
      #` TODO: stupid emacs bug

      config = subject.ezbake_config
      expect(config).to eq(nil)

      subject.ezbake_stage "ruby", "is", "junky"

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

  describe '#ezbake_make' do
    it 'run on command correctly when invoked' do
      expect(subject).to receive(:on).with(host,
                                           /make -e my_task/)
      subject.ezbake_make host, "my_task"
    end
  end

  describe '#conditionally_clone' do
    before do
      expect(subject).to receive(:ezbake_tools_available?)
    end

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
