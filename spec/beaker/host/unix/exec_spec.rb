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
  end
end
