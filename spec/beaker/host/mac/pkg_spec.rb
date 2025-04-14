require 'spec_helper'

class MacPkgTest
  include Mac::Pkg
  # CommandFactory is included in Mac::Pkg to provide us with the execute method
  include Beaker::CommandFactory

  def initialize
    @logger = RSpec::Mocks::Double.new('logger').as_null_object

    # Set up the test host to be used
    @hostname = "mac.test.com"
    @options = {}
    @test_host = Beaker::Host.create(@hostname, @options, {})
  end

  def logger
    @logger
  end
end

describe MacPkgTest do
  let(:host) { described_class.new }
  let(:result_success) { Beaker::Result.new('host', 'cmd') }
  let(:result_failure) { Beaker::Result.new('host', 'cmd') }
  let(:dmg_file) { 'test-package.dmg' }
  let(:pkg_base) { 'test-package' }
  let(:pkg_name) { 'test-package.pkg' }

  before do
    result_success.exit_code = 0
    result_failure.exit_code = 1
  end

  describe '#generic_install_dmg' do
    context 'when the DMG file does not exist' do
      it 'curls the DMG file' do
        allow(host).to receive(:execute).with("test -f #{dmg_file}", { :accept_all_exit_codes => true }).and_yield(result_failure)
        expect(host).to receive(:execute).with("curl -O #{dmg_file}")
        allow(host).to receive(:execute).with("hdiutil attach test-package.dmg")
        allow(host).to receive(:execute).with("test -f /Volumes/#{pkg_base}/#{pkg_name}", { :accept_all_exit_codes => true }).and_yield(result_success)
        allow(host).to receive(:execute).with("installer -pkg /Volumes/#{pkg_base}/#{pkg_name} -target /")

        host.generic_install_dmg(dmg_file, pkg_base, pkg_name)
      end
    end

    context 'when the specific package exists in the DMG' do
      it 'installs the specific package' do
        allow(host).to receive(:execute).with("test -f #{dmg_file}", { :accept_all_exit_codes => true }).and_yield(result_success)
        allow(host).to receive(:execute).with("hdiutil attach test-package.dmg")
        allow(host).to receive(:execute).with("test -f /Volumes/#{pkg_base}/#{pkg_name}", { :accept_all_exit_codes => true }).and_yield(result_success)
        expect(host).to receive(:execute).with("installer -pkg /Volumes/#{pkg_base}/#{pkg_name} -target /")

        host.generic_install_dmg(dmg_file, pkg_base, pkg_name)
      end
    end

    context 'when the included pkg has a different name from the dmg' do
      it 'searches for and installs the first package found' do
        allow(host).to receive(:execute).with("test -f #{dmg_file}", { :accept_all_exit_codes => true }).and_yield(result_success)
        allow(host).to receive(:execute).with("hdiutil attach test-package.dmg")
        allow(host).to receive(:execute).with("test -f /Volumes/#{pkg_base}/#{pkg_name}", { :accept_all_exit_codes => true }).and_yield(result_failure)

        # This is a bit complex as we're testing the heredoc script execution
        # We're expecting the script to be executed and are not validating its exact content
        expect(host).to receive(:execute).with(a_string_including("find /Volumes/#{pkg_base} -name \"*.pkg\" -type f -print -quit"))

        host.generic_install_dmg(dmg_file, pkg_base, pkg_name)
      end
    end
  end

  describe '#install_package' do
    it 'calls generic_install_dmg with the correct arguments' do
      expect(host).to receive(:generic_install_dmg).with("package.dmg", "package", "package.pkg")
      host.install_package("package")
    end

    it 'strips the .dmg extension if present' do
      expect(host).to receive(:generic_install_dmg).with("package.dmg", "package", "package.pkg")
      host.install_package("package.dmg")
    end
  end
end
