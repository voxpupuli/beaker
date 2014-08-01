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
      expect{ host['value'] }.to_not raise_error
    end

    it 'can be written like a hash' do
      host['value'] = 'blarg'
      expect( host['value'] ).to be === 'blarg'
    end

    describe "windows hosts" do
      describe "install_package" do
        let(:cygwin) { 'setup-x86.exe' }
        let(:cygwin64) { 'setup-x86_64.exe' }
        let(:package) { 'foo' }

        before(:each) do
          @platform = 'windows'
          host.stub(:check_for_package).and_return(true)
        end

        context "testing osarchitecture" do

          before(:each) do
            host.should_receive(:execute).with(/wmic os get osarchitecture/, anything).and_yield(success_osarch_check)
          end

          context "32 bit" do
            let(:success_osarch_check) { double(:success, :exit_code => 0, :stdout => '32-bit') }

            it "uses 32 bit cygwin" do
              host.should_receive(:execute).with(/#{cygwin}.*#{package}/)
              host.install_package(package)
            end
          end

          context "64 bit" do
            let(:success_osarch_check) { double(:success, :exit_code => 0, :stdout => '64-bit') }

            it "uses 64 bit cygwin" do
              host.should_receive(:execute).with(/#{cygwin64}.*#{package}/)
              host.install_package(package)
            end
          end
        end

        context "testing os name" do
          let(:failed_osarch_check) { double(:failed, :exit_code => 1) }

          before(:each) do
            host.should_receive(:execute).with(/wmic os get osarchitecture/, anything).and_yield(failed_osarch_check)
            host.should_receive(:execute).with(/wmic os get name/, anything).and_yield(name_check)
          end

          context "32 bit" do
            let(:name_check) { double(:failure, :exit_code => 1) }

            it "uses 32 bit cygwin" do
              host.should_receive(:execute).with(/#{cygwin}.*#{package}/)
              host.install_package(package)
            end
          end

          context "64 bit" do
            let(:name_check) { double(:success, :exit_code => 0) }

            it "uses 64 bit cygwin" do
              host.should_receive(:execute).with(/#{cygwin64}.*#{package}/)
              host.install_package(package)
            end
          end
        end
      end
    end

    describe "executing commands" do
      let(:command) { Beaker::Command.new('ls') }
      let(:host) { Beaker::Host.create('host', make_host_opts('host', options.merge(platform))) }
      let(:result) { Beaker::Result.new(host, 'ls') }

      before :each do
        result.stdout = 'stdout'
        result.stderr = 'stderr'

        logger = double(:logger)
        logger.stub(:host_output)
        logger.stub(:debug)
        host.instance_variable_set :@logger, logger
        conn = double(:connection)
        conn.stub(:execute).and_return(result)
        host.instance_variable_set :@connection, conn
      end

      it 'takes a command object and a hash of options'
      it "acts on the host's logger and connection object"
      it 'receives a result object from the connection#execute'
      it "returns the result object"

      it 'logs the amount of time spent executing the command' do
        result.exit_code = 0

        expect(host.logger).to receive(:debug).with(/executed in \d\.\d{2} seconds/)

        host.exec(command,{})
      end

      context "controls the result objects logging" do
        it "and passes a test if the exit_code doesn't match the default :acceptable_exit_codes of 0" do
          result.exit_code = 0
          expect{ host.exec(command,{}) }.to_not raise_error
        end
        it "and fails a test if the exit_code doesn't match the default :acceptable_exit_codes of 0" do
          result.exit_code = 1
          expect{ host.exec(command,{}) }.to raise_error
        end
        it "and passes a test if the exit_code matches :acceptable_exit_codes" do
          result.exit_code = 0
          expect{ host.exec(command,{:acceptable_exit_codes => 0}) }.to_not raise_error
        end
        it "and fails a test if the exit_code doesn't match :acceptable_exit_codes" do
          result.exit_code = 0
          expect{ host.exec(command,{:acceptable_exit_codes => 1}) }.to raise_error
        end
        it "and passes a test if the exit_code matches one of the :acceptable_exit_codes" do
          result.exit_code = 127
          expect{ host.exec(command,{:acceptable_exit_codes => [1,127]}) }.to_not raise_error
        end
        it "and passes a test if the exit_code matches one of the range of :acceptable_exit_codes" do
          result.exit_code = 1
          expect{ host.exec(command,{:acceptable_exit_codes => (0..127)}) }.to_not raise_error
        end
      end
    end

    context 'do_scp_to' do
      # it takes a location and a destination
      # it basically proxies that to the connection object
      it 'do_scp_to logs info and proxies to the connection' do
        File.stub(:file?).and_return(true)
        logger = host[:logger]
        conn = double(:connection)
        @options = { :logger => logger }
        host.instance_variable_set :@connection, conn
        args = [ 'source', 'target', {} ]
        conn_args = args + [ nil ]

        logger.should_receive(:debug)
        conn.should_receive(:scp_to).with( *conn_args )

        host.do_scp_to *args
      end

      context "using an ignore array" do

        before :each do
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

        it 'can take an ignore list that excludes all files and not call scp_to', :use_fakefs => true do
          logger = host[:logger]
          conn = double(:connection)
          @options = { :logger => logger }
          host.instance_variable_set :@connection, conn
          args = [ 'tmp', 'target', {:ignore => ['tests', 'tests2']} ]

          logger.should_receive(:debug)
          host.should_receive( :mkdir_p ).exactly(0).times
          conn.should_receive(:scp_to).exactly(0).times

          host.do_scp_to *args
        end

        it 'can take an ignore list that excludes a single file and scp the rest', :use_fakefs => true do
          exclude_file = '07_InstallCACerts.rb'
          logger = host[:logger]
          conn = double(:connection)
          @options = { :logger => logger }
          host.instance_variable_set :@connection, conn
          args = [ 'tmp', 'target', {:ignore => [exclude_file]} ]

          Dir.stub( :glob ).and_return( @fileset1 + @fileset2 )

          logger.should_receive(:debug)
          host.should_receive( :mkdir_p ).with('target/tmp/tests')
          host.should_receive( :mkdir_p ).with('target/tmp/tests2')
          (@fileset1 + @fileset2).each do |file|
            if file !~ /#{exclude_file}/
              file_args = [ file, File.join('target', file), {:ignore => [exclude_file]} ]
              conn_args = file_args + [ nil ]
              conn.should_receive(:scp_to).with( *conn_args )
            end
          end

          host.do_scp_to *args
        end

        it 'can take an ignore list that excludes a dir and scp the rest', :use_fakefs => true do
          exclude_file = 'tests'
          logger = host[:logger]
          conn = double(:connection)
          @options = { :logger => logger }
          host.instance_variable_set :@connection, conn
          args = [ 'tmp', 'target', {:ignore => [exclude_file]} ]

          Dir.stub( :glob ).and_return( @fileset1 + @fileset2 )

          logger.should_receive(:debug)
          host.should_receive( :mkdir_p ).with('target/tmp/tests2')
          (@fileset2).each do |file|
            file_args = [ file, File.join('target', file), {:ignore => [exclude_file]} ]
            conn_args = file_args + [ nil ]
            conn.should_receive(:scp_to).with( *conn_args )
          end

          host.do_scp_to *args
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
        conn_args = args + [ nil ]

        logger.should_receive(:debug)
        conn.should_receive(:scp_from).with( *conn_args )

        host.do_scp_from *args
      end
    end

    it 'interpolates to its "name"' do
      expect( "#{host}" ).to be === 'name'
    end

    context 'merging defaults' do
      it 'knows the difference between foss and pe' do
        @options = { :type => 'pe' }
        expect( host['puppetpath'] ).to be === '/etc/puppetlabs/puppet'
      end

    end

  end
end
