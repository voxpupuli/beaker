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
    @logger ||= RSpec::Mocks::Mock.new('logger').as_null_object
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

  describe '#ezbake_config' do
    it "returns a map with ezbake configuration parameters" do
      subject.initialize_ezbake_config
      config = subject.ezbake_config
      expect(config).to include(EZBAKE_CONFIG_EXAMPLE)
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

  describe '#ezbake_stage' do
    before do
      allow(subject).to receive(:ezbake_tools_available?) { true }
      subject.wipe_out_ezbake_config
    end

    it "initializes EZBakeUtils.config" do
      Dir.stub( :chdir ).and_yield()
      allow(subject).to receive(:conditionally_clone) { true }

      expect(subject).to receive(:`).with(/^lein.*/).ordered
      expect(subject).to receive(:`).with("rake package:bootstrap").ordered
      expect(subject).to receive(:load) { }.ordered
      expect(subject).to receive(:`).with(anything()).ordered

      config = subject.ezbake_config
      expect(config).to eq(nil)

      subject.ezbake_stage "ruby", "is", "junky"

      config = subject.ezbake_config
      expect(config).to include(EZBAKE_CONFIG_EXAMPLE)
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
    let( :platform ) { Beaker::Platform.new('redhat-7-i386') }
    let(:host) do
      FakeHost.create('fakevm', platform.to_s)
    end

    before do
      allow(subject).to receive(:ezbake_tools_available?) { true }
      subject.initialize_ezbake_config
    end

    it "Raises an exception for unsupported platforms." do
      expect{ 
        subject.install_ezbake_deps host
      }.to raise_error(RuntimeError, /No repository installation step for/)
    end

    context "When host is a debian-like platform" do
      let( :platform ) { Beaker::Platform.new('debian-7-i386') }
      include_examples "installs-ezbake-dependencies"
    end

    context "When host is a redhat-like platform" do
      let( :platform ) { Beaker::Platform.new('centos-7-i386') }
      include_examples "installs-ezbake-dependencies"
    end
  end

  def install_from_ezbake_common_expects
    expect(subject).to receive(:`).with(/rake package:tar/).ordered
    expect(subject).to receive(:scp_to).
      with( kind_of(Beaker::Host), anything(), anything()).ordered
    expect(subject).to receive(:on).
      with( kind_of(Beaker::Host), /tar -xzf/).ordered
    expect(subject).to receive(:on).
      with( kind_of(Beaker::Host), /make -e install-#{EZBAKE_CONFIG_EXAMPLE[:real_name]}/).ordered
  end

  describe '#install_from_ezbake' do
    let( :platform ) { Beaker::Platform.new('redhat-7-i386') }
    let(:host) do
      FakeHost.create('fakevm', platform.to_s)
    end

    before do
      allow(subject).to receive(:ezbake_tools_available?) { true }
    end

    context "for non *nix-like platforms" do
      let( :platform ) { Beaker::Platform.new('windows-7-i386') }
      it "raises an exception" do
        expect{ 
          subject.install_from_ezbake host, "blah", "blah"
        }.to raise_error(RuntimeError, /Beaker::DSL::EZBakeUtils unsupported platform:/)
      end
    end

    it "raises an exception for unsupported *nix-like platforms" do
      Dir.stub( :chdir ).and_yield()
      install_from_ezbake_common_expects
      expect{ 
        subject.install_from_ezbake host, "blah", "blah"
      }.to raise_error(RuntimeError, /No ezbake installation step for/)
    end

    context "When Beaker::DSL::EZBakeUtils.config is nil" do
      let( :platform ) { Beaker::Platform.new('el-7-i386') }
      before do
        Dir.stub( :chdir ).and_yield()
        subject.wipe_out_ezbake_config
      end

      it "runs ezbake_stage" do
        expect(subject).to receive(:ezbake_stage) {
          Beaker::DSL::EZBakeUtils.config = EZBAKE_CONFIG_EXAMPLE
        }.ordered
        install_from_ezbake_common_expects
        expect(subject).to receive(:on).
          with( kind_of(Beaker::Host), /install-rpm-sysv-init/).ordered
        subject.install_from_ezbake host, "blah", "blah"
      end

    end

    context "When Beaker::DSL::EZBakeUtils.config is a hash" do
      let( :platform ) { Beaker::Platform.new('el-7-i386') }
      before do
        Dir.stub( :chdir ).and_yield()
        subject.initialize_ezbake_config
      end

      it "skips ezbake_stage" do
        install_from_ezbake_common_expects
        expect(subject).to receive(:on).
          with( kind_of(Beaker::Host), /install-rpm-sysv-init/).ordered
        subject.install_from_ezbake host, "blah", "blah"
      end

    end

  end

end
