require 'spec_helper'

class ClassMixedWithDSLInstallUtils
  include Beaker::DSL::Wrappers
  include Beaker::DSL::Helpers
  include Beaker::DSL::Structure
  include Beaker::DSL::Roles
  include Beaker::DSL::Patterns
  include Beaker::DSL::InstallUtils

  def logger
    @logger ||= RSpec::Mocks::Double.new('logger').as_null_object
  end
end

describe ClassMixedWithDSLInstallUtils do
  let(:metadata)      { @metadata ||= {} }
  let(:presets)       { Beaker::Options::Presets.new }
  let(:opts)          { presets.presets.merge(presets.env_vars) }
  let(:basic_hosts)   { make_hosts( { :pe_ver => '3.0',
                                       :platform => 'linux',
                                       :roles => [ 'agent' ] }, 4 ) }
  let(:hosts)         { basic_hosts[0][:roles] = ['master', 'database', 'dashboard']
                        basic_hosts[1][:platform] = 'windows'
                        basic_hosts[2][:platform] = 'osx-10.9-x86_64'
                        basic_hosts[3][:platform] = 'eos'
                        basic_hosts  }
  let(:hosts_sorted)  { [ hosts[1], hosts[0], hosts[2], hosts[3] ] }
  let(:winhost)       { make_host( 'winhost', { :platform => 'windows',
                                                :pe_ver => '3.0',
                                                :working_dir => '/tmp',
                                                :is_cygwin => true} ) }
  let(:winhost_non_cygwin) { make_host( 'winhost_non_cygwin', { :platform => 'windows',
                                                :pe_ver => '3.0',
                                                :working_dir => '/tmp',
                                                :is_cygwin => 'false' } ) }
  let(:machost)       { make_host( 'machost', { :platform => 'osx-10.9-x86_64',
                                                :pe_ver => '3.0',
                                                :working_dir => '/tmp' } ) }
  let(:unixhost)      { make_host( 'unixhost', { :platform => 'linux',
                                                 :pe_ver => '3.0',
                                                 :working_dir => '/tmp',
                                                 :dist => 'puppet-enterprise-3.1.0-rc0-230-g36c9e5c-debian-7-i386' } ) }
  let(:eoshost)       { make_host( 'eoshost', { :platform => 'eos',
                                                :pe_ver => '3.0',
                                                :working_dir => '/tmp',
                                                :dist => 'puppet-enterprise-3.7.1-rc0-78-gffc958f-eos-4-i386' } ) }

  describe "#configure_defaults_on" do

    it "can set foss defaults" do
      expect(subject).to receive(:add_foss_defaults_on).exactly(hosts.length).times
      subject.configure_defaults_on(hosts, 'foss')
    end

    it "can set aio defaults" do
      expect(subject).to receive(:add_aio_defaults_on).exactly(hosts.length).times
      subject.configure_defaults_on(hosts, 'aio')
    end

    it "can set pe defaults" do
      expect(subject).to receive(:add_pe_defaults_on).exactly(hosts.length).times
      subject.configure_defaults_on(hosts, 'pe')
    end

    it 'can remove old defaults ands replace with new' do
      expect(subject).to receive(:remove_pe_defaults_on).exactly(hosts.length).times
      expect(subject).to receive(:add_foss_defaults_on).exactly(hosts.length).times
      subject.configure_defaults_on(hosts, 'pe')
      subject.configure_defaults_on(hosts, 'foss')
    end
  end

  describe "#configure_type_defaults_on" do

    it "can set foss defaults for foss type" do
      hosts.each do |host|
        host['type'] = 'foss'
      end
      expect(subject).to receive(:add_foss_defaults_on).exactly(hosts.length).times
      subject.configure_type_defaults_on(hosts)
    end

    it "adds aio defaults to foss hosts when they have an aio foss puppet version" do
      hosts.each do |host|
        host[:pe_ver] = nil
        host[:version] = nil
        host['type'] = 'foss'
        host['version'] = '4.0'
      end
      expect(subject).to receive(:add_foss_defaults_on).exactly(hosts.length).times
      expect(subject).to receive(:add_aio_defaults_on).exactly(hosts.length).times
      subject.configure_type_defaults_on(hosts)
    end

    it "adds aio defaults to foss hosts when they have type foss-aio" do
      hosts.each do |host|
        host[:pe_ver] = nil
        host[:version] = nil
        host['type'] = 'foss-aio'
      end
      expect(subject).to receive(:add_foss_defaults_on).exactly(hosts.length).times
      expect(subject).to receive(:add_aio_defaults_on).exactly(hosts.length).times
      subject.configure_type_defaults_on(hosts)
    end

    it "can set aio defaults for aio type (backwards compatability)" do
      hosts.each do |host|
        host[:pe_ver] = nil
        host[:version] = nil
        host['type'] = 'aio'
      end
      expect(subject).to receive(:add_aio_defaults_on).exactly(hosts.length).times
      subject.configure_type_defaults_on(hosts)
    end

    it "can set pe defaults for pe type" do
      hosts.each do |host|
        host['type'] = 'pe'
      end
      expect(subject).to receive(:add_pe_defaults_on).exactly(hosts.length).times
      subject.configure_type_defaults_on(hosts)
    end

    it "adds aio defaults to pe hosts when they an aio pe version" do
      hosts.each do |host|
        host['type'] = 'pe'
        host['pe_ver'] = '4.0'
      end
      expect(subject).to receive(:add_pe_defaults_on).exactly(hosts.length).times
      expect(subject).to receive(:add_aio_defaults_on).exactly(hosts.length).times
      subject.configure_type_defaults_on(hosts)
    end

  end
end
