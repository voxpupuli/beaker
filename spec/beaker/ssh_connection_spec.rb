require 'spec_helper'
require 'net/ssh'

module Beaker
  describe SshConnection do
    let( :host )     { 'my_host' }
    let( :user )     { 'root'    }
    let( :ssh_opts ) { {} }
    let( :options )  { { :logger => double('logger').as_null_object }  }
    subject(:connection) { SshConnection.new host, user, ssh_opts, options }

    it 'self.connect creates connects and returns a proxy for that connection' do
      # grrr
      Net::SSH.should_receive(:start).with( host, user, ssh_opts )
      connection_constructor = SshConnection.connect host, user, ssh_opts, options
      expect( connection_constructor ).to be_a_kind_of SshConnection
    end

    it 'connect creates a new connection' do
      Net::SSH.should_receive( :start ).with( host, user, ssh_opts)
      connection.connect
    end

    it 'connect caches its connection' do
      Net::SSH.should_receive( :start ).with( host, user, ssh_opts ).once.and_return true
      connection.connect
      connection.connect
    end

    it 'close runs ssh close' do
      mock_ssh = Object.new
      Net::SSH.should_receive( :start ).with( host, user, ssh_opts) { mock_ssh }
      connection.connect

      mock_ssh.should_receive( :close ).once
      connection.close
    end

    it 'close sets the @ssh variable to nil' do
      mock_ssh = Object.new
      Net::SSH.should_receive( :start ).with( host, user, ssh_opts) { mock_ssh }
      connection.connect

      mock_ssh.should_receive( :close ).once
      connection.close

      expect( connection.instance_variable_get(:@ssh) ).to be_nil
    end

    it 'close calls ssh shutdown if ssh close fails' do
      mock_ssh = Object.new
      mock_ssh.stub( :close ) { raise Error }
      Net::SSH.should_receive( :start ).with( host, user, ssh_opts) { mock_ssh }
      connection.connect

      mock_ssh.should_receive( :shutdown! ).once
      connection.close
    end

    it 'execute'
    it 'request_terminal_for'
    it 'register_stdout_for'
    it 'register_stderr_for'
    it 'register_exit_code_for'
    it 'process_stdin_for'
    it 'scp'

  end
end
