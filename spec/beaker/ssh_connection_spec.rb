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

    it 'scp_to returns 0 on successful scp' do
      mock_ssh = Object.new
      mock_scp = Object.new
      mock_ssh.stub(:scp) { mock_scp }
      mock_scp.stub(:upload!)
      Net::SSH.should_receive( :start ).with( host, user, ssh_opts) { mock_ssh }
      connection.connect

      expect( connection.scp_to("pantsMcGee", "fisherPrice").exit_code ).to be === 0
    end

    it 'scp_to returns 1 on failed scp' do
      mock_ssh = Object.new
      mock_scp = Object.new
      mock_ssh.stub(:scp) { mock_scp }
      mock_scp.stub(:upload!) { raise Net::SCP::Error }
      Net::SSH.should_receive( :start ).with( host, user, ssh_opts) { mock_ssh }
      connection.connect

      expect( connection.scp_to("pantsMcGee", "fisherPrice").exit_code ).to be === 1
    end

    it 'scp_from returns 0 on successful scp' do
      mock_ssh = Object.new
      mock_scp = Object.new
      mock_ssh.stub(:scp) { mock_scp }
      mock_scp.stub(:download!)
      Net::SSH.should_receive( :start ).with( host, user, ssh_opts) { mock_ssh }
      connection.connect

      expect( connection.scp_from("pantsMcGee", "fisherPrice").exit_code ).to be === 0
    end

    it 'scp_from returns 1 on failed scp' do
      mock_ssh = Object.new
      mock_scp = Object.new
      mock_ssh.stub(:scp) { mock_scp }
      mock_scp.stub(:download!) { raise Net::SCP::Error }
      Net::SSH.should_receive( :start ).with( host, user, ssh_opts) { mock_ssh }
      connection.connect

      expect( connection.scp_from("pantsMcGee", "fisherPrice").exit_code ).to be === 1
    end

    it 'close?'
    it 'execute'
    it 'request_terminal_for'
    it 'register_stdout_for'
    it 'register_stderr_for'
    it 'register_exit_code_for'
    it 'process_stdin_for'

  end
end
