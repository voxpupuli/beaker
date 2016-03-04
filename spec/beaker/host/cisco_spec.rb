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

        it 'ends with the :vrf host parameter' do
          vrf_answer = 'vrf_answer_135246'
          @options = {
            :vrf  => vrf_answer,
            :user => 'notroot',
          }
          answer_test = host.prepend_commands( 'fake_command' )
          expect( answer_test ).to match( /#{vrf_answer}$/ )
        end

        it 'begins with sourcing the /etc/profile script' do
          answer_test = host.prepend_commands( 'fake_command' )
          expect( answer_test ).to match( 'source /etc/profile;' )
        end

        it 'uses sudo at the beginning of the actual command to execute' do
          @options = {
            :vrf  => 'fakevrf',
            :user => 'notroot',
          }
          answer_test = host.prepend_commands( 'fake_command' )
          command_start_index = answer_test.index( ';' ) + 1
          command_actual = answer_test[command_start_index, answer_test.length - command_start_index]
          expect( command_actual ).to match( /^sudo / )
        end

        it 'guards against "vsh" usage (only scenario we dont want prefixing)' do
          answer_prepend_commands = 'pc_param_unchanged_13584'
          answer_test = host.prepend_commands( 'fake/vsh/command', answer_prepend_commands )
          expect( answer_test ).to be === answer_prepend_commands
        end
      end

      context 'for cisco_ios_xr-6' do

        before :each do
          @platform = 'cisco_ios_xr-6-x86_64'
        end

        it 'begins with sourcing the /etc/profile script' do
          answer_test = host.prepend_commands( 'fake_command' )
          expect( answer_test ).to match( /^#{Regexp.escape('source /etc/profile;')}/ )
        end

        it 'does not use sudo, as root is allowed' do
          answer_test = host.prepend_commands( 'fake_command' )
          expect( answer_test ).not_to match( /sudo/ )
        end

        it 'does prepend with the :vrf host parameter' do
          expect( host ).to receive( :[] ).with( :vrf )
          host.prepend_commands( 'fake_command' )
        end

      end
    end

    describe '#environment_string' do

      it 'starts with `env` for cisco_ios_xr-6' do
        @platform = 'cisco_ios_xr-6-x86'
        env_map = { 'PATH' => '/opt/pants/1' }
        answer_test = host.environment_string( env_map )
        expect( answer_test ).to match( /^env\ / )
      end

      it 'starts with `export` for cisco_nexus-7' do
        @platform = 'cisco_nexus-7-x86_64'
        env_map = { 'PATH' => '/opt/pants/2' }
        answer_test = host.environment_string( env_map )
        expect( answer_test ).to match( /^export\ / )
      end

      it 'ends with a semi-colon' do
        env_map = { 'PATH' => '/opt/pants/3' }
        answer_test = host.environment_string( env_map )
        expect( answer_test ).to match( /\;$/ )
      end

      it 'turns env maps into paired strings correctly' do
        @platform = 'cisco_ios_xr-6-x86_64'
        env_map = { 'var1' => 'ans1', 'var2' => 'ans2' }
        answer_correct = 'env VAR1="ans1" VAR2="ans2";'
        answer_test = host.environment_string( env_map )
        expect( answer_test ).to be === answer_correct
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