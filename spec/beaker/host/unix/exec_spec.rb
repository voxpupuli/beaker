require 'spec_helper'

module Beaker

  describe Unix::Exec do
    class UnixExecTest
      include Unix::Exec

      def initialize(hash, logger)
        @hash = hash
        @logger = logger
      end

      def [](k)
        @hash[k]
      end

      def to_s
        "me"
      end

    end

    let (:opts)     { @opts || {} }
    let (:logger)   { double( 'logger' ).as_null_object }
    let (:instance) { UnixExecTest.new(opts, logger) }

    context "rm" do

      it "deletes" do
        path = '/path/to/delete'
        expect( instance ).to receive(:execute).with("rm -rf #{path}").and_return(0)
        expect( instance.rm_rf(path) ).to be === 0
      end
    end

    context 'mv' do
      let(:origin)      { '/origin/path/of/content' }
      let(:destination) { '/destination/path/of/content' }

      it 'rm first' do
        expect( instance ).to receive(:execute).with("rm -rf #{destination}").and_return(0)
        expect( instance ).to receive(:execute).with("mv #{origin} #{destination}").and_return(0)
        expect( instance.mv(origin, destination) ).to be === 0

      end

      it 'does not rm' do
         expect( instance ).to receive(:execute).with("mv #{origin} #{destination}").and_return(0)
         expect( instance.mv(origin, destination, false) ).to be === 0
      end
    end

    describe '#environment_string' do
      let(:host) { {'pathseparator' => ':'} }

      it 'returns a blank string if theres no env' do
        expect( instance ).to receive( :is_powershell? ).never
        expect( instance.environment_string( {} ) ).to be == ''
      end

      it 'takes an env hash with var_name/value pairs' do
        expect( instance.environment_string( {:HOME => '/', :http_proxy => 'http://foo'} ) ).
          to be == 'env HOME="/" http_proxy="http://foo" HTTP_PROXY="http://foo"'
      end

      it 'takes an env hash with var_name/value[Array] pairs' do
        expect( instance.environment_string( {:LD_PATH => ['/', '/tmp']}) ).
          to be == "env LD_PATH=\"/:/tmp\""
      end
    end

    describe '#ssh_permit_user_environment' do
      context 'When called without error' do
        let (:directory) {'/directory'}
        let (:ssh_command) {"echo 'PermitUserEnvironment yes' | cat - /etc/ssh/sshd_config > #{directory}/sshd_config.permit"}
        let (:ssh_move) {"mv #{directory}/sshd_config.permit /etc/ssh/sshd_config"}

        platforms = PlatformHelpers::SYSTEMDPLATFORMS + PlatformHelpers::DEBIANPLATFORMS + PlatformHelpers::SYSTEMVPLATFORMS

        platforms.each do |platform|
          it "calls the correct commands for #{platform}" do
            opts['platform'] = platform
            expect(instance).to receive(:exec).twice
            expect(instance).to receive(:create_tmpdir_on).and_return(directory)
            expect(Beaker::Command).to receive(:new).with(ssh_move)
            expect(Beaker::Command).to receive(:new).with(ssh_command)
            expect(instance).to receive(:ssh_service_restart)
            expect{instance.ssh_permit_user_environment}.to_not raise_error
          end
        end
      end

      it 'raises an error on unsupported platforms' do
        opts['platform'] = 'notarealthing01-parts-arch'
        expect {
          instance.ssh_permit_user_environment
        }.to raise_error( ArgumentError, /#{opts['platform']}/ )
      end
    end

    describe '#ssh_service_restart' do
      PlatformHelpers::SYSTEMDPLATFORMS.each do |platform|
        it "calls the correct command for #{platform}" do
          opts['platform'] = platform 
          expect(instance).to receive(:exec)
          expect(Beaker::Command).to receive(:new).with("systemctl restart sshd.service")
          expect{instance.ssh_service_restart}.to_not raise_error
        end
      end

      PlatformHelpers::DEBIANPLATFORMS.each do |platform|
        it "calls the correct command for #{platform}" do
          opts['platform'] = platform
          expect(instance).to receive(:exec)
          expect(Beaker::Command).to receive(:new).with("service ssh restart")
          expect{instance.ssh_service_restart}.to_not raise_error
        end
      end

      PlatformHelpers::SYSTEMVPLATFORMS.each do |platform|
        it "calls the correct command for #{platform}" do
          opts['platform'] = "#{platform}-arch"
          expect(instance).to receive(:exec)
          expect(Beaker::Command).to receive(:new).with("/sbin/service sshd restart")
          expect{instance.ssh_service_restart}.to_not raise_error
        end
      end

      it 'raises an error on unsupported platforms' do
        opts['platform'] = 'notarealthing02-parts-arch'
        expect {
          instance.ssh_service_restart
        }.to raise_error( ArgumentError, /#{opts['platform']}/ )
      end
    end

    describe '#prepend_commands' do
      it 'returns the pc parameter unchanged for non-cisco platforms' do
        allow( instance ).to receive( :[] ).with( :platform ).and_return( 'notcisco' )
        answer_prepend_commands = 'pc_param_unchanged_13579'
        answer_test = instance.prepend_commands( 'fake_cmd', answer_prepend_commands )
        expect( answer_test ).to be === answer_prepend_commands
      end
    end

    describe '#selinux_enabled?' do
      it 'calls selinuxenabled and selinux is enabled' do
        expect(Beaker::Command).to receive(:new).with("sudo selinuxenabled").and_return(0)
        expect(instance).to receive(:exec).with(0, :accept_all_exit_codes => true).and_return(generate_result("test", {:exit_code => 0}))
        expect(instance.selinux_enabled?).to be === true
      end

      it 'calls selinuxenabled and selinux is not enabled' do
        expect(Beaker::Command).to receive(:new).with("sudo selinuxenabled").and_return(1)
        expect(instance).to receive(:exec).with(1, :accept_all_exit_codes => true).and_return(generate_result("test", {:exit_code => 1}))
        expect(instance.selinux_enabled?).to be === false
      end
    end

    describe '#ssh_set_user_environment' do
      before :each do
        allow( instance ).to receive( :exec )
        allow( instance ).to receive( :[] ).with( 'platform' ).and_return( 'centos-6-x86' )
        allow( instance ).to receive( :[] ).with( :ssh_env_file ).and_return( '' )
      end

      it 'adds the env argument hash to the environment' do
        allow( instance ).to receive( :mkdir_p )
        allow( instance ).to receive( :[] ).with( :ssh_env_file ).and_return( '' )

        env_hash = {
          'key1' => 'value1',
          'key2' => 'value2',
          'key3' => 'value3'
        }
        expect( instance ).to receive( :add_env_var ).with( 'PATH', '$PATH' )
        env_hash.each do |k,v|
          expect( instance ).to receive( :add_env_var ).with( k, v )
        end
        instance.ssh_set_user_environment( env_hash )
      end

      describe 'ssh env file setup' do
        before :each do
          @env_folder = '/not/real/fake/test'
          @env_folder_pathname = Pathname.new( @env_folder )
          @env_file = 'file.extension'
          @env_file_path = "#{@env_folder}/#{@env_file}"
          allow( instance ).to receive( :[] ).with( :ssh_env_file ).and_return( @env_file_path )
        end

        it 'creates the folder if needed' do
          allow( instance ).to receive( :add_env_var )
          expect( instance ).to receive( :mkdir_p ).with( @env_folder_pathname )
          instance.ssh_set_user_environment( {} )
        end

        it 'sets up the env file' do
          allow( instance ).to receive( :add_env_var )
          allow( instance ).to receive( :mkdir_p )
          expect( Beaker::Command ).to receive( :new ).with( /^chmod 0600 #{@env_folder}$/ )
          expect( Beaker::Command ).to receive( :new ).with( /^touch #{@env_file_path}$/ )
          instance.ssh_set_user_environment( {} )
        end
      end

      describe 'platform-specific setup' do
        def set_env_platform_test(platform_str, value_hash)
          allow( instance ).to receive( :mkdir_p )
          allow( instance ).to receive( :[] ).with( :ssh_env_file ).and_return( '' )
          allow( instance ).to receive( :[] ).with( 'platform' ).and_return( platform_str )

          expect( instance ).to receive( :add_env_var ).with( 'PATH', '$PATH' )
          value_hash.each do |k, v|
            expect( instance ).to receive( :add_env_var ).with( k, v )
          end
          instance.ssh_set_user_environment( {} )
        end

        it 'OSX : sets usr/local/bin' do
          set_env_platform_test( 'osx-doesnt-matter', 'PATH' => '/usr/local/bin' )
        end

        it 'SOLARIS-10: sets /opt/csw/bin' do
          set_env_platform_test( 'solaris-10-matter', 'PATH' => '/opt/csw/bin' )
        end

        it 'OPENBSD: sets PKG_PATH' do
          arch = 'arch'
          version = '9.5'
          platform_str = "openbsd-#{version}-#{arch}"
          pkg_path_regex = /^http.*openbsd.org.*#{version}.*#{arch}\/$/
          set_env_platform_test( platform_str, 'PKG_PATH' => pkg_path_regex )
        end
      end
    end
  end
end
