require 'spec_helper'
require 'net/ssh'

module PuppetAcceptance
  describe SshConnection do
    let( :host )    { 'my_host' }
    let( :user )    { 'root'    }
    let( :options ) { Hash.new  }
    subject(:connection) { SshConnection.new host, user, options }

    it 'self.connect creates connects and returns a proxy for that connection' do
      # grrr
      Net::SSH.should_receive(:start).with( host, user, options )
      connection_constructor = SshConnection.connect host, user, options
      expect( connection_constructor ).to be_a_kind_of SshConnection
    end

    it 'connect creates a new connection' do
      Net::SSH.should_receive( :start ).with( host, user, options )
      connection.connect
    end

    it 'connect caches its connection' do
      Net::SSH.should_receive( :start ).with( host, user, options ).once.and_return true
      connection.connect
      connection.connect
    end

    it 'close?'
    it 'execute'
    it 'request_terminal_for'
    it 'register_stdout_for'
    it 'register_stderr_for'
    it 'register_exit_code_for'
    it 'process_stdin_for'
    it 'scp'

  end
end
