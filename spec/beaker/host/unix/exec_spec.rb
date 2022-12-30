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

    let(:opts)     { @opts || {} }
    let(:logger)   { double( 'logger' ).as_null_object }
    let(:instance) { UnixExecTest.new(opts, logger) }

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

    describe '#modified_at' do
      it 'calls execute with touch and timestamp' do
        time = '190101010000'
        path = '/path/to/file'
        expect( instance ).to receive(:execute).with("/bin/touch -mt #{time} #{path}").and_return(0)

        instance.modified_at(path, time)
      end
    end

    describe '#environment_string' do
      let(:host) { {'pathseparator' => ':'} }

      it 'returns a blank string if theres no env' do
        expect( instance ).not_to receive( :is_powershell? )
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
        let(:directory) {'/directory'}
        let(:ssh_command) {"echo 'PermitUserEnvironment yes' | cat - /etc/ssh/sshd_config > #{directory}/sshd_config.permit"}
        let(:ssh_move) {"mv #{directory}/sshd_config.permit /etc/ssh/sshd_config"}

        platforms = PlatformHelpers::SYSTEMDPLATFORMS + PlatformHelpers::DEBIANPLATFORMS + PlatformHelpers::SYSTEMVPLATFORMS

        platforms.each do |platform|
          it "calls the correct commands for #{platform}" do
            opts['platform'] = platform
            expect(instance).to receive(:exec).twice
            expect(instance).to receive(:tmpdir).and_return(directory)
            expect(Beaker::Command).to receive(:new).with(ssh_move)
            expect(Beaker::Command).to receive(:new).with(ssh_command)
            expect(instance).to receive(:ssh_service_restart)
            expect{instance.ssh_permit_user_environment}.not_to raise_error
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
          expect{instance.ssh_service_restart}.not_to raise_error
        end
      end

      PlatformHelpers::DEBIANPLATFORMS.each do |platform|
        it "calls the correct command for #{platform}" do
          opts['platform'] = platform
          expect(instance).to receive(:exec)
          expect(Beaker::Command).to receive(:new).with("service ssh restart")
          expect{instance.ssh_service_restart}.not_to raise_error
        end
      end

      PlatformHelpers::SYSTEMVPLATFORMS.each do |platform|
        it "calls the correct command for #{platform}" do
          opts['platform'] = "#{platform}-arch"
          expect(instance).to receive(:exec)
          expect(Beaker::Command).to receive(:new).with("/sbin/service sshd restart")
          expect{instance.ssh_service_restart}.not_to raise_error
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

    describe '#reboot' do
      year = Time.now.strftime('%Y')

      check_cmd_output = {
        :centos6 => {
          :who => {
            :initial => "      system boot  #{year}-05-13 03:51",
            :success => "      system boot  #{year}-05-13 03:52",
          },
          :last => {
              :initial => <<~LAST_F,
              reboot   system boot  2.6.32-754.29.1. Tue May 5 17:34:52 #{year} - Tue May 5 17:52:48 #{year}  (00:17)
              reboot   system boot  2.6.32-754.29.1. Mon May 4 18:45:43 #{year} - Mon May 5 05:35:44 #{year} (4+01:50)
              LAST_F
              :success => <<~LAST_F,
              reboot   system boot  2.6.32-754.29.1. Tue May 5 17:52:48 #{year} - Tue May 5 17:52:49 #{year}  (00:17)
              reboot   system boot  2.6.32-754.29.1. Mon May 4 18:45:43 #{year} - Mon May 5 05:35:44 #{year} (4+01:50)
              LAST_F
          },
        },
        :centos7 => {
          :who => {
            :initial => "      system boot  #{year}-05-13 03:51",
            :success => "      system boot  #{year}-05-13 03:52",
          },
          :last => {
              :initial => <<~LAST_F,
              reboot   system boot  3.10.0-1127.el7. Tue May 5 17:34:52 #{year} - Tue May 5 17:52:48 #{year}  (00:17)
              reboot   system boot  3.10.0-1127.el7. Mon May 4 18:45:43 #{year} - Mon May 5 05:35:44 #{year} (4+01:50)
              LAST_F
              :success => <<~LAST_F,
              reboot   system boot  3.10.0-1127.el7. Tue May 5 17:52:48 #{year} - Tue May 5 17:52:49 #{year}  (00:17)
              reboot   system boot  3.10.0-1127.el7. Mon May 4 18:45:43 #{year} - Mon May 5 05:35:44 #{year} (4+01:50)
              LAST_F
          },
        },
        :centos8 => {
          :who => {
            :initial => "      system boot  #{year}-05-13 03:51",
            :success => "      system boot  #{year}-05-13 03:52",
          },
          :last => {
              :initial => <<~LAST_F,
              reboot   system boot  4.18.0-147.8.1.e Tue May 5 17:34:52 #{year} still running
              reboot   system boot  4.18.0-147.8.1.e Mon May 4 17:41:27 #{year} - Tue May 5 17:00:00 #{year} (5+00:11)
              LAST_F
              :success => <<~LAST_F,
              reboot   system boot  4.18.0-147.8.1.e Tue May 5 17:34:53 #{year} still running
              reboot   system boot  4.18.0-147.8.1.e Mon May 4 17:41:27 #{year} - Tue May 5 17:00:00 #{year} (5+00:11)
              LAST_F
          },
        },
        :freebsd => {
          # last -F doesn't work on freebsd so no output will be returned
          :who => {
            :initial => '      system boot  May 13 03:51',
            :success => '      system boot  May 13 03:52',
          }
        },
      }

      # no-op response
      let(:response) { double( 'response' ) }
      let(:boot_time_initial_response) { double( 'response' ) }

      let(:boot_time_success_response) { double( 'response' ) }
      let(:sleep_time) { 10 }

      before do
        # stubs enough to survive the first boot_time call & output parsing
        #   note: just stubs input-chain between calls, parsing methods still run
        allow(Beaker::Command).to receive(:new).with('last -F reboot || who -b').and_return(:boot_time_command_stub)

        allow(boot_time_initial_response).to receive(:stdout).and_return(boot_time_initial_stdout)
        allow(boot_time_success_response).to receive(:stdout).and_return(boot_time_success_stdout)

        allow(instance).to receive(:sleep)

        allow(Beaker::Command).to receive(:new).with("/bin/systemctl reboot -i || reboot || /sbin/shutdown -r now").and_return(:shutdown_command_stub)
      end

      context 'new boot time greater than old boot time' do
        check_cmd_output.each do |check_os, cmd_opts|
          cmd_opts.each do |cmd_name, cmd_outputs|
            context "on '#{check_os}' with the '#{cmd_name}' command" do
              let(:boot_time_initial_stdout) { cmd_outputs[:initial] }
              let(:boot_time_success_stdout) { cmd_outputs[:success] }

              it 'passes with defaults' do
                expect(instance).to receive(:sleep).with(sleep_time)
                # bypass shutdown command itself
                expect(instance).to receive( :exec ).with(:shutdown_command_stub, anything).and_return(response)
                expect(instance).to receive( :exec ).with(:boot_time_command_stub, anything).and_return(boot_time_initial_response).once
                # allow the second boot_time and the hash arguments in exec
                expect(instance).to receive( :exec ).with(:boot_time_command_stub, anything).and_return(boot_time_success_response).once

                expect(instance.reboot).to be(nil)
              end

              it 'passes with wait_time_parameter' do
                expect(instance).to receive(:sleep).with(10)
                # bypass shutdown command itself
                expect(instance).to receive( :exec ).with(:shutdown_command_stub, anything).and_return(response).once
                expect(instance).to receive( :exec ).with(:boot_time_command_stub, anything).and_return(boot_time_initial_response).once
                # allow the second boot_time and the hash arguments in exec
                expect(instance).to receive( :exec ).with(:boot_time_command_stub, anything).and_return(boot_time_success_response).once

                expect(instance.reboot(10)).to be(nil)
              end

              it 'passes with max_connection_tries parameter' do
                expect(instance).to receive(:sleep).with(sleep_time)
                # bypass shutdown command itself
                expect(instance).to receive( :exec ).with(:shutdown_command_stub, anything).and_return(response).once
                expect(instance).to receive( :exec ).with(:boot_time_command_stub, anything).and_return(boot_time_initial_response).once
                # allow the second boot_time and the hash arguments in exec
                expect(instance).to receive( :exec ).with(:boot_time_command_stub, hash_including(:max_connection_tries => 20)).and_return(boot_time_success_response).once

                expect(instance.reboot(sleep_time, 20)).to be(nil)
              end

              context 'command errors' do
                before do
                  allow(instance).to receive( :exec ).with(:boot_time_command_stub, anything).and_return(boot_time_initial_response).at_least(:once)
                end

                it 'raises a reboot failure when command fails' do
                  expect(instance).to receive(:sleep).at_least(:once)
                  expect(instance).to receive(:exec).with(:shutdown_command_stub, anything).and_raise(Host::CommandFailure).at_least(:once)

                  expect{ instance.reboot }.to raise_error(Beaker::Host::CommandFailure)
                end

                it 'raises a reboot failure when we receive an unexpected error' do
                  expect(instance).to receive(:sleep).at_least(:once)
                  expect(instance).to receive(:exec).with(:shutdown_command_stub, anything).and_raise(Net::SSH::HostKeyError).at_least(:once)

                  expect { instance.reboot }.to raise_error(Net::SSH::HostKeyError)
                end

                context 'incorrect time string' do
                  context 'original time' do
                    let(:boot_time_initial_stdout) { 'boot bad' }

                    it 'raises a reboot failure' do
                      # Handle the 'retry'
                      allow(instance).to receive( :exec ).with(:boot_time_command_stub, anything).and_return(boot_time_initial_response).at_least(:once)

                      expect(instance).not_to receive(:sleep)

                      expect { instance.reboot }.to raise_error(Beaker::Host::RebootWarning, /Found no valid times in .*/)
                    end
                  end

                  context 'current time' do
                    let(:boot_time_success_stdout) { 'boot bad' }

                    it 'raises a reboot failure' do
                      expect(instance).to receive(:exec).with(:shutdown_command_stub, anything).and_return(response).once
                      expect(instance).to receive( :exec ).with(:boot_time_command_stub, anything).and_return(boot_time_initial_response).once
                      # allow the second boot_time and the hash arguments in exec, repeated 10 times by default
                      expect(instance).to receive( :exec ).with(:boot_time_command_stub, anything).and_return(boot_time_success_response).at_least(:once)

                      expect { instance.reboot(10,9,1) }.to raise_error(Beaker::Host::RebootWarning, /Found no valid times in .*/)
                    end
                  end
                end
              end
            end
          end
        end
      end

      context 'system did not reboot' do
        check_cmd_output.each do |check_os, cmd_opts|
          cmd_opts.each do |cmd_name, cmd_outputs|
            context "on '#{check_os}' with the '#{cmd_name}' command" do
              let(:boot_time_initial_stdout) { cmd_outputs[:initial] }
              let(:boot_time_success_stdout) { cmd_outputs[:initial] }

              it 'raises RebootFailure' do
                expect(instance).to receive(:sleep).with(sleep_time)
                # bypass shutdown command itself
                expect(instance).to receive( :exec ).with(:shutdown_command_stub, anything).and_return(response).once

                expect(instance).to receive( :exec ).with(:boot_time_command_stub, anything).and_return(boot_time_initial_response).once
                expect(instance).to receive( :exec ).with(:boot_time_command_stub, anything).and_return(boot_time_success_response).once

                expect { instance.reboot }.to raise_error(Beaker::Host::RebootFailure, /Boot time did not reset/)
              end

              it 'raises RebootFailure if the number of retries is changed' do
                expect(instance).to receive(:sleep).with(sleep_time)
                # bypass shutdown command itself
                expect(instance).to receive( :exec ).with(:shutdown_command_stub, anything).and_return(response).once
                expect(instance).to receive( :exec ).with(:boot_time_command_stub, anything).and_return(boot_time_initial_response).once
                expect(instance).to receive( :exec ).with(:boot_time_command_stub, anything).and_return(boot_time_success_response).once

                expect { instance.reboot(sleep_time, 9, 10) }.to raise_error(Beaker::Host::RebootFailure, /Boot time did not reset/)
              end
            end
          end
        end
      end
    end

    describe '#enable_remote_rsyslog' do
      it 'always calls restart' do
        opts['platform'] = 'ubuntu-18-x86_64'
        allow(Beaker::Command).to receive(:new).with(anything)
        allow(instance).to receive(:exec)
        expect(Beaker::Command).to receive(:new).with("systemctl restart rsyslog")
        instance.enable_remote_rsyslog
      end

    end

    describe '#which' do
      context 'when type -P works' do
        before do
          expect(instance).to receive(:execute)
            .with('type -P true', :accept_all_exit_codes => true).and_return('/bin/true').once

          allow(instance).to receive(:execute)
                                 .with(where_command, :accept_all_exit_codes => true).and_return(result)
        end

        context 'when only the environment variable PATH is used' do
          let(:where_command) { "type -P ruby" }
          let(:result) { "/usr/bin/ruby.exe" }

          it 'returns the correct path' do
            response = instance.which('ruby')

            expect(response).to eq(result)
          end
        end

        context 'when command is not found' do
          let(:where_command) { "type -P unknown" }
          let(:result) { '' }

          it 'return empty string if command is not found' do
            response = instance.which('unknown')

            expect(response).to eq(result)
          end
        end
      end

      context 'when which works' do
        before do
          expect(instance).to receive(:execute)
            .with('type -P true', :accept_all_exit_codes => true).and_return('').once

          expect(instance).to receive(:execute)
            .with('which true', :accept_all_exit_codes => true).and_return('/bin/true').once

          allow(instance).to receive(:execute)
                                 .with(where_command, :accept_all_exit_codes => true).and_return(result)
        end

        context 'when only the environment variable PATH is used' do
          let(:where_command) { "which ruby" }
          let(:result) { "/usr/bin/ruby.exe" }

          it 'returns the correct path' do
            response = instance.which('ruby')

            expect(response).to eq(result)
          end
        end

        context 'when command is not found' do
          let(:where_command) { "which unknown" }
          let(:result) { '' }

          it 'return empty string if command is not found' do
            response = instance.which('unknown')

            expect(response).to eq(result)
          end
        end
      end

      context 'when neither works' do
        before do
          expect(instance).to receive(:execute)
            .with('type -P true', :accept_all_exit_codes => true).and_return('').once

          expect(instance).to receive(:execute)
            .with('which true', :accept_all_exit_codes => true).and_return('').once
        end

        context 'when only the environment variable PATH is used' do
          it 'fails correctly' do
            expect{instance.which('ruby')}.to raise_error(/suitable/)
          end
        end
      end
    end
  end
end
