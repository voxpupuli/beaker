require 'spec_helper'

module Beaker
  describe Host do
    let(:options)  { @options ? @options : {} }
    let(:platform) { @platform ? { :platform => @platform } : {} }
    let(:host)    { make_host( 'name', options.merge(platform) ) }

    it 'creates a windows host given a windows config' do
      @platform = 'windows'
      expect( host ).to be_a_kind_of Windows::Host
    end

    it 'defaults to a unix host' do
      expect( host ).to be_a_kind_of Unix::Host
    end

    it 'can be read like a hash' do
      expect{ host['value'] }.not_to raise_error
    end

    it 'can be written like a hash' do
      host['value'] = 'blarg'
      expect( host['value'] ).to be === 'blarg'
    end

    describe "host types" do
      let(:options) { Beaker::Options::OptionsHash.new }

      it "can be a pe host" do
        options['type'] = 'pe'
        expect(host).to be_is_pe
        expect(host).to be_use_service_scripts
        expect(host).to be_is_using_passenger
        expect(host).not_to be_graceful_restarts
      end

      it "can be a foss-source host" do
        expect(host).not_to be_is_pe
        expect(host).not_to be_use_service_scripts
        expect(host).not_to be_is_using_passenger
      end

      it "can be a foss-package host" do
        options['use-service'] = true
        expect(host).not_to be_is_pe
        expect(host).to be_use_service_scripts
        expect(host).not_to be_is_using_passenger
        expect(host).not_to be_graceful_restarts
      end

      it "can be a foss-packaged host using passenger" do
        host.uses_passenger!
        expect(host).not_to be_is_pe
        expect(host).to be_use_service_scripts
        expect(host).to be_is_using_passenger
        expect(host).to be_graceful_restarts
      end

      it 'can be an AIO host' do
        options['type'] = 'aio'
        expect(host).not_to be_is_pe
        expect(host).not_to be_use_service_scripts
        expect(host).not_to be_is_using_passenger
      end

      it 'sets the paths correctly for an AIO host' do
        options['type'] = 'aio'
        expect(host['puppetvardir']).to be_nil
      end
    end

    describe "uses_passenger!" do
      it "sets passenger property" do
        host.uses_passenger!
        expect(host['passenger']).to be_truthy
        expect(host).to be_is_using_passenger
      end

      it "sets puppetservice" do
        host.uses_passenger!('servicescript')
        expect(host['puppetservice']).to eq('servicescript')
      end

      it "sets puppetservice to apache2 by default" do
        host.uses_passenger!
        expect(host['puppetservice']).to eq('apache2')
      end
    end

    describe "graceful_restarts?" do
      it "is true if graceful-restarts property is set true" do
        options['graceful-restarts'] = true
        expect(host).to be_graceful_restarts
      end

      it "is false if graceful-restarts property is set false" do
        options['graceful-restarts'] = false
        expect(host).not_to be_graceful_restarts
      end

      it "is false if is_pe and graceful-restarts is nil" do
        options['type'] = 'pe'
        expect(host).not_to be_graceful_restarts
      end

      it "is true if is_pe and graceful-restarts is true" do
        options['type'] = 'pe'
        options['graceful-restarts'] = true
        expect(host).to be_graceful_restarts
      end

      it "falls back to passenger property if not pe and graceful-restarts is nil" do
        host.uses_passenger!
        expect(host).to be_graceful_restarts
      end
    end

    describe "windows hosts" do
      describe "install_package" do
        let(:cygwin) { 'setup-x86.exe' }
        let(:cygwin64) { 'setup-x86_64.exe' }
        let(:package) { 'foo' }

        context "testing osarchitecture" do

          context "64 bit" do
            before do
              @platform = Beaker::Platform.new('windows-2008r2-64')
            end

            it "uses 64 bit cygwin" do
              expect( host ).to receive(:execute).with(/#{cygwin64}.*#{package}/)
              host.install_package(package)
            end
          end

          context "32 bit" do
            before do
              @platform = Beaker::Platform.new('windows-10ent-32')
            end

            it "uses 32 bit cygwin" do
              expect( host ).to receive(:execute).with(/#{cygwin}.*#{package}/)
              host.install_package(package)
            end
          end
        end

      end
    end

    describe "#add_env_var" do

      it "does nothing if the key/value pair already exists" do
        result = Beaker::Result.new(host, '')
        result.exit_code = 0
        expect( Beaker::Command ).to receive(:new).with("grep ^key=.*\\/my\\/first\\/value ~/.ssh/environment")
        expect( host ).to receive(:exec).once.and_return(result)

        host.add_env_var('key', '/my/first/value')
      end

      it "adds new line to environment file if no env var of that name already exists" do
        result = Beaker::Result.new(host, '')
        result.exit_code = 1
        expect( Beaker::Command ).to receive(:new).with("grep ^key=.*\\/my\\/first\\/value ~/.ssh/environment")
        expect( host ).to receive(:exec).and_return(result)
        expect( Beaker::Command ).to receive(:new).with(/grep \^key= ~\/\.ssh\/environment/)
        expect( host ).to receive(:exec).and_return(result)
        expect( Beaker::Command ).to receive(:new).with("echo \"key=/my/first/value\" >> ~/.ssh/environment")
        host.add_env_var('key', '/my/first/value')
      end

      it "updates existing line in environment file when adding additional value to existing variable" do
        result = Beaker::Result.new(host, '')
        result.exit_code = 1
        expect( Beaker::Command ).to receive(:new).with("grep ^key=.*\\/my\\/first\\/value ~/.ssh/environment")
        expect( host ).to receive(:exec).and_return(result)
        result = Beaker::Result.new(host, '')
        result.exit_code = 0
        expect( Beaker::Command ).to receive(:new).with(/grep \^key= ~\/\.ssh\/environment/)
        expect( host ).to receive(:exec).and_return(result)
        expect( Beaker::SedCommand ).to receive(:new).with('unix', 's/^key=/key=\\/my\\/first\\/value:/', '~/.ssh/environment')
        host.add_env_var('key', '/my/first/value')
      end

    end

    describe "#delete_env_var" do
      it "deletes env var" do
        expect( Beaker::SedCommand ).to receive(:new).with('unix', '/key=\\/my\\/first\\/value$/d', '~/.ssh/environment')
        expect( Beaker::SedCommand ).to receive(:new).with("unix", "s/key=\\(.*\\)[;:]\\/my\\/first\\/value/key=\\1/", "~/.ssh/environment")
        expect( Beaker::SedCommand ).to receive(:new).with("unix", "s/key=\\/my\\/first\\/value[;:]/key=/", "~/.ssh/environment")
        host.delete_env_var('key', '/my/first/value')
      end

    end

    describe "executing commands" do
      let(:command) { Beaker::Command.new('ls') }
      let(:host) { described_class.create('host', {}, make_host_opts('host', options.merge(platform))) }
      let(:result) { Beaker::Result.new(host, 'ls') }

      before do
        result.stdout = 'stdout'
        result.stderr = 'stderr'

        logger = double(:logger)
        allow( logger ).to receive(:host_output)
        allow( logger ).to receive(:debug)
        allow( logger ).to receive(:with_indent).and_yield
        host.instance_variable_set :@logger, logger
        conn = double(:connection)
        allow( conn ).to receive(:execute).and_return(result)
        allow( conn ).to receive(:ip).and_return(host['ip'])
        allow( conn ).to receive(:vmhostname).and_return(host['vmhostname'])
        allow( conn ).to receive(:hostname).and_return(host.name)
        host.instance_variable_set :@connection, conn
      end

      it 'takes a command object and a hash of options' do
        result.exit_code = 0
        expect{ host.exec(command, {}) }.not_to raise_error
      end

      it 'acts on the host\'s logger and connection object' do
        result.exit_code = 0
        expect( host.instance_variable_get(:@logger) ).to receive(:debug).at_least(:once)
        expect( host.instance_variable_get(:@connection) ).to receive(:execute).once
        host.exec(command)
      end

      it 'returns the result object' do
        result.exit_code = 0
        expect( host.exec(command) ).to be === result
      end

      it 'logs the amount of time spent executing the command' do
        result.exit_code = 0

        expect(host.logger).to receive(:debug).with(/executed in \d\.\d{2} seconds/)

        host.exec(command,{})
      end

      it 'raises a CommandFailure when an unacceptable exit code is returned' do
        result.exit_code = 7
        opts = { :acceptable_exit_codes => [0, 1] }

        expect { host.exec(command, opts) }.to raise_error(Beaker::Host::CommandFailure)
      end

      it 'raises a CommandFailure when an unacceptable exit code is returned and the accept_all_exit_codes flag is set to false' do
        result.exit_code = 7
        opts = {
          :acceptable_exit_codes => [0, 1],
          :accept_all_exit_codes => false
        }

        expect { host.exec(command, opts) }.to raise_error(Beaker::Host::CommandFailure)
      end

      it 'does throw an error when an unacceptable exit code is returned and the accept_all_exit_codes flag is set' do
        result.exit_code = 7
        opts = {
          :acceptable_exit_codes  => [0, 1],
          :accept_all_exit_codes  => true
        }
        allow( host.logger ).to receive( :warn )

        expect { host.exec(command, opts) }.to raise_error
      end

      it 'sends a warning when both :acceptable_exit_codes & :accept_all_exit_codes are set' do
        result.exit_code = 1
        opts = {
          :acceptable_exit_codes  => [0, 1],
          :accept_all_exit_codes  => true
        }
        expect( host.logger ).to receive( :warn ).with( /overrides/ )

        expect { host.exec(command, opts) }.not_to raise_error
      end

      it 'explicitly closes the connection when :reset_connection is set' do
        expect( host ).to receive( :close )
        expect { host.exec(command, :reset_connection => true) }.not_to raise_error
      end

      context "controls the result objects logging" do
        it "and passes a test if the exit_code doesn't match the default :acceptable_exit_codes of 0" do
          result.exit_code = 0
          expect{ host.exec(command,{}) }.not_to raise_error
        end

        it "and fails a test if the exit_code doesn't match the default :acceptable_exit_codes of 0" do
          result.exit_code = 1
          expect{ host.exec(command,{}) }.to raise_error
        end

        it "and passes a test if the exit_code matches :acceptable_exit_codes" do
          result.exit_code = 0
          expect{ host.exec(command,{:acceptable_exit_codes => 0}) }.not_to raise_error
        end

        it "and fails a test if the exit_code doesn't match :acceptable_exit_codes" do
          result.exit_code = 0
          expect{ host.exec(command,{:acceptable_exit_codes => 1}) }.to raise_error
        end

        it "and passes a test if the exit_code matches one of the :acceptable_exit_codes" do
          result.exit_code = 127
          expect{ host.exec(command,{:acceptable_exit_codes => [1,127]}) }.not_to raise_error
        end

        it "and passes a test if the exit_code matches one of the range of :acceptable_exit_codes" do
          result.exit_code = 1
          expect{ host.exec(command,{:acceptable_exit_codes => (0..127)}) }.not_to raise_error
        end
      end
    end

    describe "#mkdir_p" do

      it "does the right thing on a bash host, identified as is_cygwin=true" do
        @options = {:is_cygwin => true}
        @platform = 'windows'
        result = double
        allow( result ).to receive( :exit_code ).and_return( 0 )
        allow( host ).to receive( :exec ).and_return( result )

        expect( Beaker::Command ).to receive(:new).with("mkdir -p \"test/test/test\"")
        expect( host.mkdir_p('test/test/test') ).to be == true

      end

      it "does the right thing on a bash host, identified as is_cygwin=nil" do
        @options = {:is_cygwin => nil}
        @platform = 'windows'
        result = double
        allow( result ).to receive( :exit_code ).and_return( 0 )
        allow( host ).to receive( :exec ).and_return( result )

        expect( Beaker::Command ).to receive(:new).with("mkdir -p \"test/test/test\"")
        expect( host.mkdir_p('test/test/test') ).to be == true

      end

      it "does the right thing on a non-bash host, identified as is_cygwin=false (powershell)" do
        @options = {:is_cygwin => false}
        @platform = 'windows'
        result = double
        allow( result ).to receive( :exit_code ).and_return( 0 )
        allow( host ).to receive( :exec ).and_return( result )

        expect( Beaker::Command ).to receive(:new).
          with("powershell.exe", ["-ExecutionPolicy Bypass",
                                  "-InputFormat None",
                                  "-NoLogo",
                                  "-NoProfile",
                                  "-NonInteractive",
                                  "-Command New-Item -Path 'test\\test\\test' -ItemType 'directory'"])
        expect( host.mkdir_p('test/test/test') ).to be == true

      end

    end

    describe "#touch" do

      it "generates the right absolute command for a windows host" do
        @platform = 'windows'
        expect( host.touch('touched_file') ).to be == "c:\\\\windows\\\\system32\\\\cmd.exe /c echo. 2> touched_file"
      end

      ['centos','redhat'].each do |platform|
        it "generates the right absolute command for a #{platform} host" do
          @platform = platform
          expect( host.touch('touched_file') ).to be == "/bin/touch touched_file"
        end
      end

      it "generates the right absolute command for an osx host" do
        @platform = 'osx'
        expect( host.touch('touched_file') ).to be == "/usr/bin/touch touched_file"
      end

    end

    context 'do_scp_to' do
      # it takes a location and a destination
      # it basically proxies that to the connection object
      it 'do_scp_to logs info and proxies to the connection' do
        create_files(['source'])
        logger = host[:logger]
        conn = double(:connection)
        @options = { :logger => logger }
        host.instance_variable_set :@connection, conn
        args = [ '/source', 'target', {} ]
        conn_args = args

        expect( logger ).to receive(:trace)
        expect( conn ).to receive(:scp_to).with( *conn_args ).and_return(Beaker::Result.new(host, 'output!'))
        allow( conn ).to receive(:ip).and_return(host['ip'])
        allow( conn ).to receive(:vmhostname).and_return(host['vmhostname'])
        allow( conn ).to receive(:hostname).and_return(host.name)

        host.do_scp_to(*args)
      end

      it 'calls for host scp post operations after SCPing happens' do
        create_files(['source'])
        logger = host[:logger]
        conn = double(:connection)
        @options = { :logger => logger }
        host.instance_variable_set :@connection, conn
        args = [ '/source', 'target', {} ]
        conn_args = args

        allow( logger ).to receive(:trace)
        expect( conn ).to receive(:scp_to).ordered.with(
          *conn_args
        ).and_return(Beaker::Result.new(host, 'output!'))
        allow( conn ).to receive(:ip).and_return(host['ip'])
        allow( conn ).to receive(:vmhostname).and_return(host['vmhostname'])
        allow( conn ).to receive(:hostname).and_return(host.name)
        expect( host ).to receive( :scp_post_operations ).ordered

        host.do_scp_to(*args)
      end

      it 'throws an IOError when the file given doesn\'t exist' do
        expect { host.do_scp_to "/does/not/exist", "does/not/exist/over/there", {} }.to raise_error(IOError)
      end

      context "using an ignore array with an absolute source path" do
        let( :source_path ) { '/repos/puppetlabs-inifile' }
        let( :target_path ) { '/etc/puppetlabs/modules/inifile' }

        before do
          test_dir = "#{source_path}/tests"
          other_test_dir = "#{source_path}/tests2"

          files = [
              '00_EnvSetup.rb', '035_StopFirewall.rb', '05_HieraSetup.rb',
              '01_TestSetup.rb', '03_PuppetMasterSanity.rb',
              '06_InstallModules.rb','02_PuppetUserAndGroup.rb',
              '04_ValidateSignCert.rb', '07_InstallCACerts.rb'              ]

          @fileset1 = files.shuffle.map {|file| test_dir + '/' + file }
          @fileset2 = files.shuffle.map {|file| other_test_dir + '/' + file }

          create_files( @fileset1 )
          create_files( @fileset2 )
        end

        it 'can take an ignore list that excludes all files and not call scp_to' do
          logger = host[:logger]
          conn = double(:connection)
          @options = { :logger => logger }
          host.instance_variable_set :@connection, conn
          args = [ source_path, target_path, {:ignore => ['tests', 'tests2']} ]

          expect( logger ).to receive(:trace)
          expect( host ).to receive( :mkdir_p ).exactly(0).times
          expect( conn ).to receive(:scp_to).exactly(0).times

          host.do_scp_to(*args)
        end

        it 'can take an ignore list that excludes a single file and scp the rest' do
          created_target_path = File.join(target_path, File.basename(source_path))
          exclude_file = '07_InstallCACerts.rb'
          logger = host[:logger]
          conn = double(:connection)
          @options = { :logger => logger }
          host.instance_variable_set :@connection, conn
          args = [ source_path, target_path, {:ignore => [exclude_file], :dry_run => false} ]

          allow( Dir ).to receive( :glob ).and_return( @fileset1 + @fileset2 )

          expect( logger ).to receive(:trace)
          expect( host ).to receive( :mkdir_p ).with("#{created_target_path}/tests")
          expect( host ).to receive( :mkdir_p ).with("#{created_target_path}/tests2")

          (@fileset1 + @fileset2).each do |file|
            if !/#{exclude_file}/.match?(file)
              file_args = [ file, File.join(created_target_path, File.dirname(file).gsub(source_path,'')), {:ignore => [exclude_file], :dry_run => false} ]
              conn_args = file_args
              expect( conn ).to receive(:scp_to).with( *conn_args ).and_return(Beaker::Result.new(host, 'output!'))
            else
              file_args = [ file, File.join(created_target_path, File.dirname(file).gsub(source_path,'')), {:ignore => [exclude_file], :dry_run => false} ]
              conn_args = file_args
              expect( conn ).not_to receive(:scp_to).with( *conn_args )
            end
          end
          allow( conn ).to receive(:ip).and_return(host['ip'])
          allow( conn ).to receive(:vmhostname).and_return(host['vmhostname'])
          allow( conn ).to receive(:hostname).and_return(host.name)

          host.do_scp_to(*args)
        end
      end

      context "using an ignore array with an absolute source path in host root" do
        let( :source_path ) { '/puppetlabs-inifile' }
        let( :target_path ) { '/etc/puppetlabs/modules/inifile' }

        before do
          test_dir = "#{source_path}/tests"
          other_test_dir = "#{source_path}/tests/tests2"
          another_test_dir = "#{source_path}/tests/tests3"

          files = [
              '00_EnvSetup.rb', '035_StopFirewall.rb', '05_HieraSetup.rb',
              '01_TestSetup.rb', '03_PuppetMasterSanity.rb',
              '06_InstallModules.rb','02_PuppetUserAndGroup.rb',
              '04_ValidateSignCert.rb', '07_InstallCACerts.rb'              ]

          @fileset1 = files.shuffle.map {|file| test_dir + '/' + file }
          @fileset2 = files.shuffle.map {|file| other_test_dir + '/' + file }
          @fileset3 = files.shuffle.map {|file| another_test_dir + '/' + file }

          create_files( @fileset1 )
          create_files( @fileset2 )
          create_files( @fileset3 )
        end

        it "creates target dirs with correct path seperator" do
          create_files(['source'])
          exclude_file = '04_ValidateSignCert.rb'
          logger = host[:logger]
          conn = double(:connection)
          @options = { :logger => logger }
          host.instance_variable_set :@connection, conn
          args = [ source_path, target_path, {:ignore => [exclude_file]} ]
          conn_args = args

          allow( Dir ).to receive( :glob ).and_return( @fileset1 + @fileset2 + @fileset3)

          created_target_path = File.join(target_path, File.basename(source_path))
          expect( host ).to receive( :mkdir_p ).with("#{created_target_path}/tests")
          expect( host ).to receive( :mkdir_p ).with("#{created_target_path}/tests/tests2")
          expect( host ).to receive( :mkdir_p ).with("#{created_target_path}/tests/tests3")

          (@fileset1 + @fileset2 + @fileset3).each do |file|
            if !/#{exclude_file}/.match?(file)
              file_args = [ file, File.join(created_target_path, File.dirname(file).gsub(source_path,'')), {:ignore => [exclude_file], :dry_run => false} ]
              conn_args = file_args
              expect( conn ).to receive(:scp_to).with( *conn_args ).and_return(Beaker::Result.new(host, 'output!'))
            else
              file_args = [ file, File.join(created_target_path, File.dirname(file).gsub(source_path,'')), {:ignore => [exclude_file], :dry_run => false} ]
              conn_args = file_args
              expect( conn ).not_to receive(:scp_to).with( *conn_args )
            end
          end
          allow( conn ).to receive(:ip).and_return(host['ip'])
          allow( conn ).to receive(:vmhostname).and_return(host['vmhostname'])
          allow( conn ).to receive(:hostname).and_return(host.name)

          host.do_scp_to(*args)
        end
      end

      context "using an ignore array" do

        before do
          test_dir = 'tmp/tests'
          other_test_dir = 'tmp/tests2'

          files = [
            '00_EnvSetup.rb', '035_StopFirewall.rb', '05_HieraSetup.rb',
            '01_TestSetup.rb', '03_PuppetMasterSanity.rb',
            '06_InstallModules.rb','02_PuppetUserAndGroup.rb',
            '04_ValidateSignCert.rb', '07_InstallCACerts.rb'              ]

          @fileset1 = files.shuffle.map {|file| test_dir + '/' + file }
          @fileset2 = files.shuffle.map {|file| other_test_dir + '/' + file }

          create_files( @fileset1 )
          create_files( @fileset2 )
        end

        it 'can take an ignore list that excludes all files and not call scp_to' do
          logger = host[:logger]
          conn = double(:connection)
          @options = { :logger => logger }
          host.instance_variable_set :@connection, conn
          args = [ 'tmp', 'target', {:ignore => ['tests', 'tests2']} ]

          expect( logger ).to receive(:trace)
          expect( host ).to receive( :mkdir_p ).exactly(0).times
          expect( conn ).to receive(:scp_to).exactly(0).times

          host.do_scp_to(*args)
        end

        it 'can take an ignore list that excludes a single file and scp the rest' do
          exclude_file = '07_InstallCACerts.rb'
          logger = host[:logger]
          conn = double(:connection)
          @options = { :logger => logger }
          host.instance_variable_set :@connection, conn
          args = [ 'tmp', 'target', {:ignore => [exclude_file], :dry_run => false} ]

          allow( Dir ).to receive( :glob ).and_return( @fileset1 + @fileset2 )

          expect( logger ).to receive(:trace)
          expect( host ).to receive( :mkdir_p ).with('target/tmp/tests')
          expect( host ).to receive( :mkdir_p ).with('target/tmp/tests2')
          (@fileset1 + @fileset2).each do |file|
            if !/#{exclude_file}/.match?(file)
              file_args = [ file, File.join('target', File.dirname(file)), {:ignore => [exclude_file], :dry_run => false} ]
              conn_args = file_args
              expect( conn ).to receive(:scp_to).with( *conn_args ).and_return(Beaker::Result.new(host, 'output!'))
            else
              file_args = [ file, File.join('target', File.dirname(file)), {:ignore => [exclude_file], :dry_run => false} ]
              conn_args = file_args
              expect( conn ).not_to receive(:scp_to).with( *conn_args )
            end
          end
          allow( conn ).to receive(:ip).and_return(host['ip'])
          allow( conn ).to receive(:vmhostname).and_return(host['vmhostname'])
          allow( conn ).to receive(:hostname).and_return(host.name)
          host.do_scp_to(*args)
        end

        it 'can take an ignore list that excludes a dir and scp the rest' do
          exclude_file = 'tests'
          logger = host[:logger]
          conn = double(:connection)
          @options = { :logger => logger }
          host.instance_variable_set :@connection, conn
          args = [ 'tmp', 'target', {:ignore => [exclude_file], :dry_run => false} ]

          allow( Dir ).to receive( :glob ).and_return( @fileset1 + @fileset2 )

          expect( logger ).to receive(:trace)
          expect( host ).not_to receive( :mkdir_p ).with('target/tmp/tests')
          expect( host ).to receive( :mkdir_p ).with('target/tmp/tests2')
          (@fileset1).each do |file|
            file_args = [ file, File.join('target', File.dirname(file)), {:ignore => [exclude_file], :dry_run => false} ]
            conn_args = file_args
            expect( conn ).not_to receive(:scp_to).with( *conn_args )
          end
          (@fileset2).each do |file|
            file_args = [ file, File.join('target', File.dirname(file)), {:ignore => [exclude_file], :dry_run => false} ]
            conn_args = file_args
            expect( conn ).to receive(:scp_to).with( *conn_args ).and_return(Beaker::Result.new(host, 'output!'))
          end

          allow( conn ).to receive(:ip).and_return(host['ip'])
          allow( conn ).to receive(:vmhostname).and_return(host['vmhostname'])
          allow( conn ).to receive(:hostname).and_return(host.name)
          host.do_scp_to(*args)
        end
      end
    end

    context 'do_scp_from' do
      it 'do_scp_from logs info and proxies to the connection' do
        logger = host[:logger]
        conn = double(:connection)
        @options = { :logger => logger }
        host.instance_variable_set :@connection, conn
        args = [ 'source', 'target', {} ]
        conn_args = args

        expect( logger ).to receive(:debug)
        expect( conn ).to receive(:scp_from).with( *conn_args ).and_return(Beaker::Result.new(host, 'output!'))

        allow( conn ).to receive(:ip).and_return(host['ip'])
        allow( conn ).to receive(:vmhostname).and_return(host['vmhostname'])
        allow( conn ).to receive(:hostname).and_return(host.name)
        host.do_scp_from(*args)
      end
    end

    context 'do_rsync_to' do
      it 'do_rsync_to logs info and call Rsync class' do
        create_files(['source'])
        logger = host[:logger]
        @options = { :logger => logger }
        args = [ 'source', 'target', {:ignore => ['.bundle']} ]

        key = host['ssh']['keys'].first
        expect( File ).to receive( :exist? ).with( key ).and_return true

        rsync_args = [ 'source', 'target', ['-az', "-e \"ssh -i #{key} -p 22 -o 'StrictHostKeyChecking no'\"", "--exclude '.bundle'"] ]

        expect( host ).to receive(:reachable_name).and_return('default.ip.address')

        expect( Rsync ).to receive(:run).with( *rsync_args ).and_return(Rsync::Result.new('raw rsync output', 0))

        host.do_rsync_to(*args)

        expect(Rsync.host).to eq('root@default.ip.address')
      end

      it 'throws an IOError when the file given doesn\'t exist' do
        expect { host.do_rsync_to "/does/not/exist", "does/not/exist/over/there", {} }.to raise_error(IOError)
      end

      it 'uses the ssh config file' do
        @options = {'ssh' => {:config => '/var/folders/v0/centos-64-x6420150625-48025-lu3u86'}}
        create_files(['source'])
        args = [ 'source', 'target',
                 {:ignore => ['.bundle']} ]
        # since were using fakefs we need to create the file and directories
        FileUtils.mkdir_p('/var/folders/v0/')
        FileUtils.touch('/var/folders/v0/centos-64-x6420150625-48025-lu3u86')
        rsync_args = [ 'source', 'target', ['-az', "-e \"ssh -F /var/folders/v0/centos-64-x6420150625-48025-lu3u86 -o 'StrictHostKeyChecking no'\"", "--exclude '.bundle'"] ]
        expect(Rsync).to receive(:run).with(*rsync_args).and_return(Rsync::Result.new('raw rsync output', 0))
        expect(host.do_rsync_to(*args).success?).to eq(true)
      end

      it 'does not use the ssh config file when config does not exist' do
        @options = {'ssh' => {:config => '/var/folders/v0/centos-64-x6420150625-48025-lu3u86'}}
        create_files(['source'])
        args = [ 'source', 'target',
                 {:ignore => ['.bundle']} ]
        rsync_args = [ 'source', 'target', ['-az', "-e \"ssh -o 'StrictHostKeyChecking no'\"", "--exclude '.bundle'"] ]
        expect(Rsync).to receive(:run).with(*rsync_args).and_return(Rsync::Result.new('raw rsync output', 0))
        expect(host.do_rsync_to(*args).success?).to eq(true)
      end

      it "doesn't corrupt :ignore option" do
        create_files(['source'])

        ignore_list = ['.bundle']
        args = ['source', 'target', {:ignore => ignore_list}]

        key = host['ssh']['keys'].first
        expect( File ).to receive( :exist? ).with( key ).twice.and_return true

        rsync_args = ['source', 'target', ['-az', "-e \"ssh -i #{key} -p 22 -o 'StrictHostKeyChecking no'\"", "--exclude '.bundle'"]]
        expect(Rsync).to receive(:run).twice.with(*rsync_args).and_return(Rsync::Result.new('raw rsync output', 0))

        host.do_rsync_to(*args)
        host.do_rsync_to(*args)
      end
    end

    it 'interpolates to its "name"' do
      expect( "#{host}" ).to be === 'name'
    end

    describe 'host close' do
      context 'with a nil connection object' do
        before do
          conn = nil
          host.instance_variable_set :@connection, conn
          allow(host).to receive(:close).and_call_original
        end

        it 'does not raise an error' do
          expect { host.close }.not_to raise_error
        end
      end
    end

    describe '#get_public_ip' do
      let(:aws) { double('AWSmock')}

      it 'calls upon the ec2 instance to get the ip address' do
        host.host_hash[:hypervisor] = 'ec2'
        host.host_hash[:instance] = aws
        expect(aws).to receive(:ip_address)
        host.get_public_ip
      end

      it 'call upon openstack host to get the ip address' do
        host.host_hash[:hypervisor] = 'openstack'
        expect(host.get_public_ip).to be(host.host_hash[:ip])
      end

      it 'returns nil when no matching hypervisor is found' do
        host.host_hash[:hypervisor] = 'vmpooler'
        expect(host.get_public_ip).to be(nil)
      end

      it 'calls execute with curl if the host_hash[:instance] is not defined for ec2 and the host is not an instance of Windows::Host' do
        host.host_hash[:hypervisor] = 'ec2'
        host.host_hash[:instance] = nil
        expect(host).to receive(:instance_of?).with(Windows::Host).and_return(false)
        expect(host).to receive(:execute).with("curl http://169.254.169.254/latest/meta-data/public-ipv4").and_return('127.0.0.1')
        host.get_public_ip
      end

      it 'calls execute with wget if the host_hash[:instance] is not defined for ec2 and the host is an instance of Windows::Host' do
        host.host_hash[:hypervisor] = 'ec2'
        host.host_hash[:instance] = nil
        expect(host).to receive(:instance_of?).with(Windows::Host).and_return(true)
        expect(host).to receive(:execute).with("wget http://169.254.169.254/latest/meta-data/public-ipv4").and_return('127.0.0.1')
        host.get_public_ip
      end

      it 'calls execute with curl if the host_hash[:ip] is not defined for openstack and the host is not an instance of Windows::Host' do
        host.host_hash[:hypervisor] = 'openstack'
        host.host_hash[:ip] = nil
        expect(host).to receive(:instance_of?).with(Windows::Host).and_return(false)
        expect(host).to receive(:execute).with("curl http://169.254.169.254/latest/meta-data/public-ipv4").and_return('127.0.0.1')
        host.get_public_ip
      end

      it 'calls execute with wget if the host_hash[:ip] is not defined for openstack and the host is an instance of Windows::Host' do
        host.host_hash[:hypervisor] = 'openstack'
        host.host_hash[:ip] = nil
        expect(host).to receive(:instance_of?).with(Windows::Host).and_return(true)
        expect(host).to receive(:execute).with("wget http://169.254.169.254/latest/meta-data/public-ipv4").and_return('127.0.0.1')
        host.get_public_ip
      end

    end

    describe '#ip' do
      it 'calls #get_ip when get_public_ip returns nil' do
        allow( host ).to receive(:get_public_ip).and_return(nil)
        expect(host).to receive(:get_ip).and_return('127.0.0.2')
        expect(host.ip).to eq('127.0.0.2')
      end

      it 'does not call get_ip when #get_public_ip returns an address' do
        allow( host ).to receive(:get_public_ip).and_return('127.0.0.1')
        expect(host).not_to receive(:get_ip)
        expect(host.ip).to eq('127.0.0.1')
      end
    end

    describe "#wait_for_port" do
      it 'returns true when port is open' do
        allow(host).to receive(:repeat_fibonacci_style_for).and_return(true)
        expect(host.wait_for_port(22, 0)).to be true
      end

      it 'returns false when port is not open' do
        allow(host).to receive(:repeat_fibonacci_style_for).and_return(false)
        expect(host.wait_for_port(22, 0)).to be false
      end
    end

    describe "#fips_mode?" do
      it 'returns false on non-linux hosts' do
        @platform = 'windows'
        expect(host).to receive(:file_exist?).with('/proc/sys/crypto/fips_enabled').and_return(false)
        expect(host.fips_mode?).to be false
      end

      platforms = ['el-7', 'el-8', 'centos']

      platforms.each do |platform|
        context "on #{platform}" do
          it 'returns true when the `fips_enabled` file is present and contains "1"' do
            @platform = platform
            expect(host).to receive(:file_exist?).with('/proc/sys/crypto/fips_enabled').and_return(true)
            expect(host).to receive(:execute).with("cat /proc/sys/crypto/fips_enabled").and_return("1")
            expect(host.fips_mode?).to be true
          end

          it 'returns false when the `fips_enabled` file is present and contains "0"' do
            @platform = platform
            expect(host).to receive(:execute).with("cat /proc/sys/crypto/fips_enabled").and_return("0")
            expect(host.fips_mode?).to be false
          end
        end
      end
    end
  end
end
