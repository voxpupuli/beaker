require 'spec_helper'

module Cisco
  describe Host do
    let(:options)  { @options ? @options : {} }
    let(:platform) {
      if @platform
        { :platform => Beaker::Platform.new( @platform) }
      else
        { :platform => Beaker::Platform.new( 'cisco_nexus-vers-arch-extra' ) }
      end
    }
    let(:host)    { make_host( 'name', options.merge(platform) ) }

    describe '#prepend_commands' do

      context 'for cisco_nexus-7' do

        before :each do
          @platform = 'cisco_nexus-7-x86_64'
        end

        it 'starts with sourcing the /etc/profile script' do
          answer_correct = 'source /etc/profile;'
          answer_test = host.prepend_commands( 'fake_command' )
          expect( answer_test ).to be === answer_correct
        end

        it 'uses `sudo` if not root' do
          @options = { :user => 'notroot' }
          answer_correct = "source /etc/profile; sudo -E sh -c \""
          answer_test = host.prepend_commands( 'fake_command' )
          expect( answer_test ).to be === answer_correct
        end

        it 'ends with the :vrf host parameter' do
          vrf_answer = 'vrf_answer_135246'
          @options = {
            :vrf  => vrf_answer,
          }
          answer_test = host.prepend_commands( 'fake_command' )
          expect( answer_test ).to match( /ip netns exec #{vrf_answer}$/ )
        end

        it 'guards against "vsh" usage (scenario we never want prefixing)' do
          answer_user_pc = 'pc_param_unchanged_13584'
          answer_test = host.prepend_commands( 'fake/vsh/command', answer_user_pc )
          expect( answer_test ).to be === answer_user_pc
        end

        it 'guards against "ntpdate" usage (we dont want prefixing on nexus)' do
          answer_user_pc = 'user_pc_param_54321'
          answer_test = host.prepend_commands( 'fake/ntpdate/command', answer_user_pc )
          expect( answer_test ).to be === answer_user_pc
        end


        it 'retains user-specified prepend commands when adding vrf' do
          @options = {
            :vrf  => 'fakevrf',
          }
          answer_prepend_commands = 'prepend'
          answer_correct = 'source /etc/profile;ip netns exec fakevrf prepend'
          answer_test = host.prepend_commands( 'fake_command', answer_prepend_commands )
          expect( answer_test ).to be === answer_correct
        end
      end

      context 'for cisco_ios_xr-6' do

        before :each do
          @platform = 'cisco_ios_xr-6-x86_64'
        end

        it 'starts with sourcing the /etc/profile script' do
          answer_correct = 'source /etc/profile;'
          answer_test = host.prepend_commands( 'fake_command' )
          expect( answer_test ).to be === answer_correct
        end

        it 'does use the :vrf host parameter if provided' do
          @options = { :vrf => 'tpnns' }
          answer_test = host.prepend_commands( 'fake_command' )
          expect( answer_test ).to match( /ip netns exec tpnns/ )
        end

        it 'does not guard "ntpdate" usage' do
          answer_user_pc = 'user_pc_param_54321'
          answer_correct = 'source /etc/profile;user_pc_param_54321'
          answer_test = host.prepend_commands( 'fake/ntpdate/command', answer_user_pc )
          expect( answer_test ).to be === answer_correct
        end

        it 'retains user-specified prepend commands when adding vrf' do
          @options = { :vrf  => 'fakevrf', }
          answer_prepend_commands = 'prepend'
          answer_correct = 'source /etc/profile;ip netns exec fakevrf prepend'
          answer_test = host.prepend_commands( 'fake_command', answer_prepend_commands )
          expect( answer_test ).to be === answer_correct
        end
      end
    end

    describe '#environment_string' do

      context 'for cisco_nexus-7' do

        before :each do
          @platform = 'cisco_nexus-7-x86_64'
        end

        it 'uses `export` if root' do
          @options = { :user => 'root' }
          env_map = { 'PATH' => '/opt/pants/2' }
          answer_correct = ' export PATH="/opt/pants/2";'
          answer_test = host.environment_string( env_map )
          expect( answer_test ).to be === answer_correct
        end

        it 'ends with a semi-colon' do
          env_map = { 'PATH' => '/opt/pants/3' }
          answer_test = host.environment_string( env_map )
          expect( answer_test ).to match( /\;$/ )
        end

        it 'turns env maps into paired strings correctly' do
          @options = { :user => 'root' }
          env_map = { 'var1' => 'ans1', 'VAR2' => 'ans2' }
          answer_correct = ' export var1="ans1" VAR1="ans1" VAR2="ans2";'
          answer_test = host.environment_string( env_map )
          expect( answer_test ).to be === answer_correct
        end
      end

      context 'for cisco_ios_xr-6' do
        before :each do
          @platform = 'cisco_ios_xr-6-x86_64'
        end

        it 'uses `sudo` if not root' do
          @options = { :user => 'notroot' }
          env_map = { 'PATH' => '/opt/pants/2' }
          answer_correct = ' env PATH="/opt/pants/2"'
          answer_test = host.environment_string( env_map )
          expect( answer_test ).to be === answer_correct
        end

        it 'uses `env` if root' do
          @options = { :user => 'root' }
          env_map = { 'PATH' => '/opt/pants/1' }
          answer_correct = ' env PATH="/opt/pants/1"'
          answer_test = host.environment_string( env_map )
          expect( answer_test ).to be === answer_correct
        end

        it 'does not end with a semi-colon' do
          env_map = { 'PATH' => '/opt/pants/3' }
          answer_test = host.environment_string( env_map )
          expect( answer_test ).not_to match( /\;$/ )
        end

        it 'turns env maps into paired strings correctly' do
          @options = { :user => 'root' }
          env_map = { 'VAR1' => 'ans1', 'var2' => 'ans2' }
          answer_correct = ' env VAR1="ans1" var2="ans2" VAR2="ans2"'
          answer_test = host.environment_string( env_map )
          expect( answer_test ).to be === answer_correct
        end
      end
    end

    describe '#package_config_dir' do

      it 'returns correctly for cisco platforms' do
        @platform = 'cisco_nexus-7-x86_64'
        expect( host.package_config_dir ).to be === '/etc/yum/repos.d/'
      end
    end

    describe '#repo_type' do

      it 'returns correctly for cisco platforms' do
        @platform = 'cisco_nexus-7-x86_64'
        expect( host.repo_type ).to be === 'rpm'
      end
    end

    describe '#validate_setup' do

      context 'on the cisco_nexus-7 platform' do
        before :each do
          @platform = 'cisco_nexus-7-x86_64'
        end

        it 'errors when no :vrf value is provided' do
          expect {
            host.validate_setup
          }.to raise_error( ArgumentError, /provided\ with\ a\ \:vrf\ value/ )
        end

        it 'errors when no :user value is provided' do
          @options = {
            :vrf  => 'fake_vrf',
            :user => nil,
          }
          expect {
            host.validate_setup
          }.to raise_error( ArgumentError, /provided\ with\ a\ \:user\ value/ )
        end

        it 'does nothing if the host is setup correctly' do
          @options = {
            :vrf  => 'fake_vrf',
            :user => 'notroot',
          }
          validate_test = host.validate_setup
          expect( validate_test ).to be_nil
        end
      end

      context 'on the cisco_ios_xr-6 platform' do
        before :each do
          @platform = 'cisco_ios_xr-6-x86_64'
        end

        it 'does nothing if no :vrf value is provided' do
          @options = {
              :user => 'notroot',
          }
          validate_test = host.validate_setup
          expect( validate_test ).to be_nil
        end

        it 'errors when no user is provided' do
          @options = {
            :vrf  => 'fake_vrf',
            :user => nil,
          }
          expect {
            host.validate_setup
          }.to raise_error( ArgumentError, /provided\ with\ a\ \:user\ value/ )
        end

        it 'does nothing if the host is setup correctly' do
          @options = {
            :vrf  => 'fake_vrf',
            :user => 'notroot',
          }
          validate_test = host.validate_setup
          expect( validate_test ).to be_nil
        end
      end
    end
  end
end
