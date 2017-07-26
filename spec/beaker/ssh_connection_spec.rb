require 'spec_helper'
require 'net/ssh'

module Beaker
  describe SshConnection do
    let( :user )      { 'root'    }
    let( :ssh_opts )  { { keepalive: true, keepalive_interval: 2 } }
    let( :options )   { { :logger => double('logger').as_null_object }  }
    let( :ip )        { "default.ip.address" }
    let( :vmhostname ){ "vmhostname" }
    let( :hostname)   { "my_host" }
    let( :name_hash ) { { :ip => ip, :vmhostname => vmhostname, :hostname => hostname } }
    subject(:connection) { SshConnection.new name_hash, user, ssh_opts, options }

    before :each do
      allow( subject ).to receive(:sleep)
    end

    it 'self.connect creates connects and returns a proxy for that connection' do
      # grrr
      expect( Net::SSH ).to receive(:start).with( vmhostname, user, ssh_opts ).and_return(true)
      connection_constructor = SshConnection.connect name_hash, user, ssh_opts, options
      expect( connection_constructor ).to be_a_kind_of SshConnection
    end

    it 'connect creates a new connection' do
      expect( Net::SSH ).to receive( :start ).with( vmhostname, user, ssh_opts).and_return(true)
      connection.connect
    end

    it 'connect caches its connection' do
      expect( Net::SSH ).to receive( :start ).with( vmhostname, user, ssh_opts ).once.and_return true
      connection.connect
      connection.connect
    end

    it 'attempts to connect by ip address if vmhostname connection fails' do
      expect( Net::SSH ).to receive( :start ).with( vmhostname, user, ssh_opts).and_return(false)
      expect( Net::SSH ).to receive( :start ).with( ip, user, ssh_opts).and_return(true).once
      expect( Net::SSH ).to receive( :start ).with( hostname, user, ssh_opts).never
      connection.connect
    end

    it 'attempts to connect by hostname, if vmhost + ipaddress have failed' do
      expect( Net::SSH ).to receive( :start ).with( ip, user, ssh_opts).and_return(false)
      expect( Net::SSH ).to receive( :start ).with( vmhostname, user, ssh_opts).and_return(false)
      expect( Net::SSH ).to receive( :start ).with( hostname, user, ssh_opts).and_return(true).once
      connection.connect

    end

    describe '#close' do

      it 'runs ssh close' do
        mock_ssh = Object.new
        expect( Net::SSH ).to receive( :start ).with( vmhostname, user, ssh_opts) { mock_ssh }
        connection.connect

        allow( mock_ssh).to receive( :closed? ).once.and_return(false)
        expect( mock_ssh ).to receive( :close ).once
        connection.close
      end

      it 'sets the @ssh variable to nil' do
        mock_ssh = Object.new
        expect( Net::SSH ).to receive( :start ).with( vmhostname, user, ssh_opts) { mock_ssh }
        connection.connect

        allow( mock_ssh).to receive( :closed? ).once.and_return(false)
        expect( mock_ssh ).to receive( :close ).once
        connection.close

        expect( connection.instance_variable_get(:@ssh) ).to be_nil
      end

      it 'calls ssh shutdown & re-raises if ssh close fails with an unexpected Error' do
        mock_ssh = Object.new
        allow( mock_ssh ).to receive( :close ) { raise StandardError }
        expect( Net::SSH ).to receive( :start ).with( vmhostname, user, ssh_opts) { mock_ssh }
        connection.connect

        allow( mock_ssh).to receive( :closed? ).once.and_return(false)
        expect( mock_ssh ).to receive( :shutdown! ).once
        expect{ connection.close }.to raise_error(StandardError)
        expect( connection.instance_variable_get(:@ssh) ).to be_nil
      end

    end

    describe '#execute' do
      it 'retries if failed with a retryable exception' do
        mock_ssh = Object.new
        expect( Net::SSH ).to receive( :start ).with( vmhostname, user, ssh_opts) { mock_ssh }
        connection.connect

        allow( subject ).to receive( :close )
        expect( subject ).to receive( :try_to_execute ).ordered.once { raise Timeout::Error }
        expect( subject ).to receive( :try_to_execute ).ordered.once { Beaker::Result.new('name', 'ls') }
        expect( subject ).to_not receive( :try_to_execute )
        connection.execute('ls')
      end

      it 'raises an error if it fails both times' do
        mock_ssh = Object.new
        expect( Net::SSH ).to receive( :start ).with( vmhostname, user, ssh_opts) { mock_ssh }
        connection.connect

        allow( subject ).to receive( :close )
        allow( subject ).to receive( :try_to_execute ) { raise Timeout::Error }

        expect{ connection.execute('ls') }.to raise_error Timeout::Error
      end
    end

    describe '#request_terminal_for' do
      it 'fails correctly by raising Net::SSH::Exception' do
        mock_ssh = Object.new
        expect( Net::SSH ).to receive( :start ).with( vmhostname, user, ssh_opts) { mock_ssh }
        connection.connect

        mock_channel = Object.new
        allow( mock_channel ).to receive( :request_pty ).and_yield(nil, false)

        expect{ connection.request_terminal_for mock_channel, 'ls' }.to raise_error Net::SSH::Exception
      end
    end

    describe '#register_stdout_for' do
      before :each do
        @mock_ssh = Object.new
        expect( Net::SSH ).to receive( :start ).with( vmhostname, user, ssh_opts) { @mock_ssh }
        connection.connect

        @data = '7 of clubs'
        @mock_channel = Object.new
        allow( @mock_channel ).to receive( :on_data ).and_yield(nil, @data)

        @mock_output = Object.new
        @mock_output_stdout = Object.new
        @mock_output_output = Object.new
        allow( @mock_output ).to receive( :stdout ) { @mock_output_stdout }
        allow( @mock_output ).to receive( :output ) { @mock_output_output }
        allow( @mock_output_stdout ).to receive( :<< )
        allow( @mock_output_output ).to receive( :<< )
      end

      it 'puts data into stdout & output correctly' do
        expect( @mock_output_stdout ).to receive( :<< ).with(@data)
        expect( @mock_output_output ).to receive( :<< ).with(@data)

        connection.register_stdout_for @mock_channel, @mock_output
      end

      it 'calls the callback if given' do
        @mock_callback = Object.new
        expect( @mock_callback ).to receive( :[] ).with(@data)

        connection.register_stdout_for @mock_channel, @mock_output, @mock_callback
      end
    end

    describe '#register_stderr_for' do
      let( :result ) { Beaker::Result.new('hostname', 'command') }

      before :each do
        @mock_ssh = Object.new
        expect( Net::SSH ).to receive( :start ).with( vmhostname, user, ssh_opts) { @mock_ssh }
        connection.connect

        @data = '3 of spades'
        @mock_channel = Object.new
        allow( @mock_channel ).to receive( :on_extended_data ).and_yield(nil, 1, @data)
      end

      it 'puts data into stderr & output correctly' do
        expect( result.stderr ).to receive( :<< ).with(@data)
        expect( result.output ).to receive( :<< ).with(@data)

        connection.register_stderr_for @mock_channel, result
      end

      it 'calls the callback if given' do
        @mock_callback = Object.new
        expect( @mock_callback ).to receive( :[] ).with(@data)

        connection.register_stderr_for @mock_channel, result, @mock_callback
      end

      it 'skips everything if type is not 1' do
        allow( @mock_channel ).to receive( :on_extended_data ).and_yield(nil, '1', @data)

        @mock_callback = Object.new
        expect( @mock_callback ).to_not receive( :[] )
        expect( result.stderr ).to_not receive( :<< )
        expect( result.output ).to_not receive( :<< )

        connection.register_stderr_for @mock_channel, result, @mock_callback
      end
    end

    describe '#register_exit_code_for' do
      let( :result ) { Beaker::Result.new('hostname', 'command') }

      it 'assigns the output\'s exit code correctly from the data' do
        mock_ssh = Object.new
        expect( Net::SSH ).to receive( :start ).with( vmhostname, user, ssh_opts) { mock_ssh }
        connection.connect

        data = '10 of jeromes'
        mock_data = Object.new
        allow( mock_data ).to receive( :read_long ) { data }
        mock_channel = Object.new
        allow( mock_channel ).to receive( :on_request ).with('exit-status').and_yield(nil, mock_data)

        connection.register_exit_code_for mock_channel, result
        expect( result.exit_code ).to be === data
      end
    end

    describe 'process_stdin_for' do
      it 'calls the correct channel methods in order' do
        stdin = 'jean shorts'
        mock_channel = Object.new

        expect( mock_channel ).to receive( :send_data ).with(stdin).ordered.once
        expect( mock_channel ).to receive( :process ).ordered.once
        expect( mock_channel ).to receive( :eof! ).ordered.once

        connection.process_stdin_for mock_channel, stdin
      end
    end

    describe '#scp_to' do
      before :each do
        @mock_ssh = Object.new
        @mock_scp = Object.new
        allow( @mock_scp ).to receive( :upload! )
        allow( @mock_ssh ).to receive( :scp ).and_return( @mock_scp )
        expect( Net::SSH ).to receive( :start ).with( vmhostname, user, ssh_opts) { @mock_ssh }
        connection.connect
      end

      it 'calls scp.upload!' do
        expect( @mock_scp ).to receive( :upload! ).once
        connection.scp_to '', ''
      end

      it 'ensures the connection closes when scp.upload! errors' do
        expect( @mock_scp ).to receive( :upload! ).once.and_raise(RuntimeError)
        expect(connection).to receive(:close).once
        connection.scp_to '', ''
      end

      it 'returns a result object' do
        expect( connection.scp_to '', '' ).to be_a_kind_of Beaker::Result
      end

    end

    describe '#scp_from' do
      before :each do
        @mock_ssh = Object.new
        @mock_scp = Object.new
        allow( @mock_scp ).to receive( :download! )
        allow( @mock_ssh ).to receive( :scp ).and_return( @mock_scp )
        expect( Net::SSH ).to receive( :start ).with( vmhostname, user, ssh_opts) { @mock_ssh }
        connection.connect
      end

      it 'calls scp.download!' do
        expect( @mock_scp ).to receive( :download! ).once
        connection.scp_from '', ''
      end

      it 'ensures the connection closes when scp.download! errors' do
        expect( @mock_scp ).to receive( :download! ).once.and_raise(RuntimeError)
        expect(connection).to receive(:close).once
        connection.scp_from '', ''
      end

      it 'returns a result object' do
        expect( connection.scp_from '', '' ).to be_a_kind_of Beaker::Result
      end

    end

  end
end
