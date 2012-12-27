require 'spec_helper'

class PuppetCommandsMixedIntoTestCase
  include PuppetAcceptance::PuppetCommands
end

describe PuppetCommandsMixedIntoTestCase do

  context ': A user can test puppet with specific settings and run mode' do
    context 'on one or more hosts' do
      context '#with_puppet_running_on correctly delegates to ' +
      'with_puppet_running_on_a' do

        let(:mode) { :agent }
        let(:config_opts) { {:agent => {:server => 'host2'}} }
        let(:block) { lambda {|h| 'more testing on configured hosts' } }

        it 'if given a single host' do
          host = 'host'
          subject.should_receive( :with_puppet_running_on_a ).once

          subject.with_puppet_running_on host, mode, config_opts, &block
        end

        it 'or a collection of hosts' do
          hosts = [ 'host1', 'host2', 'host3', 'host4' ]
          subject.should_receive( :with_puppet_running_on_a ).
            exactly(4).times

          subject.with_puppet_running_on hosts, mode, config_opts, &block
        end
      end
    end

    context 'when yielding tests to #with_puppet_running_on' do
      specify 'puppet runs in the mode specified'
      specify 'and with the options specified'
    end

    context 'and after running tests' do
      specify 'puppet is in the run state it was prior to the test'
      specify 'puppet is configured as it was prior to the test'

      context 'in a known location' do
        specify 'backup the original puppet.conf'
        specify 'backup the tested puppet.conf'
      end
    end
  end
end
