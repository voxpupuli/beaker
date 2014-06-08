require 'spec_helper'

EZBAKE_CONFIG_EXAMPLE= { 
  :project => 'jvm-puppet',
  :real_name => 'jvm-puppet',
  :user => 'puppet',
  :group => 'puppet',
  :uberjar_name => 'jvm-puppet-release.jar',
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
  let( :opts )     { Beaker::Options::Presets.env_vars }
  let( :host ) { double.as_null_object }
  let( :config ) { }

  describe '#ezbake_config' do
    it "returns a map with ezbake configuration parameters" do
      subject.initialize_ezbake_config
      config = subject.ezbake_config
      expect(config).to include(EZBAKE_CONFIG_EXAMPLE)
    end
  end

  describe '#ezbake_stage' do
    before do
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
      expect(subject).to receive(:install_package_version).
        with( kind_of(FakeHost), anything(), anything())
      subject.install_ezbake_deps host
    end
  end

  describe '#install_ezbake_deps' do
    let(:platform) { 'paper' }
    let(:host) do
      FakeHost.new( :options => { 'platform' => platform })
    end

    before do
      subject.initialize_ezbake_config
    end

    it "Raises an exception for unsupported platforms." do
      expect{ 
        subject.install_ezbake_deps host
      }.to raise_error(RuntimeError, /No repository installation step for/)
    end

    context "When host is a debian-like platform" do
      let(:platform) { 'debian-7-x86_64' }
      include_examples "installs-ezbake-dependencies"
    end

    context "When host is a redhat-like platform" do
      let(:platform) { 'el-6-x86_64' }
      include_examples "installs-ezbake-dependencies"
    end
  end

  def install_from_ezbake_common_expects
    expect(subject).to receive(:`).with(/rake package:tar/).ordered
    expect(subject).to receive(:scp_to).
      with( kind_of(FakeHost), anything(), anything()).ordered
    expect(subject).to receive(:on).
      with( kind_of(FakeHost), /tar -xzf/).ordered
    expect(subject).to receive(:on).
      with( kind_of(FakeHost), /make -e install-#{EZBAKE_CONFIG_EXAMPLE[:real_name]}/).ordered
  end

  describe '#install_from_ezbake' do
    let(:platform) { 'paper' }
    let(:host) do
      FakeHost.new( :options => { 'platform' => platform })
    end

    it "Raises an exception for unsuppoted platforms" do
      Dir.stub( :chdir ).and_yield()
      install_from_ezbake_common_expects
      expect{ 
        subject.install_from_ezbake host, "blah", "blah"
      }.to raise_error(RuntimeError, /No ezbake installation step for/)
    end

    context "When Beaker::DSL::EZBakeUtils.config is nil" do
      let(:platform) { 'el-6-x86_64' }
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
          with( kind_of(FakeHost), /install-rpm-sysv-init/).ordered
        subject.install_from_ezbake host, "blah", "blah"
      end

    end

    context "When Beaker::DSL::EZBakeUtils.config is a hash" do
      let(:platform) { 'el-6-x86_64' }
      before do
        Dir.stub( :chdir ).and_yield()
        subject.initialize_ezbake_config
      end

      it "skips ezbake_stage" do
        install_from_ezbake_common_expects
        expect(subject).to receive(:on).
          with( kind_of(FakeHost), /install-rpm-sysv-init/).ordered
        subject.install_from_ezbake host, "blah", "blah"
      end

    end

  end

end
