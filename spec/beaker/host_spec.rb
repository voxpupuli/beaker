require 'spec_helper'

module Beaker
  describe Host do
    let(:defaults) { Beaker::Options::OptionsHash.new.merge({'HOSTS' => {'name' => {'platform' => @platform}}})}
    let(:options) { @options ? defaults.merge(@options) : defaults}

    let(:host)    { Host.create 'name', options }

    it 'creates a windows host given a windows config' do
      @options = {'HOSTS'=> {'name' => {'platform' => 'windows'}}}
      expect( host ).to be_a_kind_of Windows::Host
    end

    it 'defaults to a unix host' do 
      expect( host ).to be_a_kind_of Unix::Host 
    end

    it 'can be read like a hash' do
      expect { host['value'] }.to_not raise_error NoMethodError
    end

    it 'can be written like a hash' do
      host['value'] = 'blarg'
      expect( host['value'] ).to be === 'blarg'
    end


    # it takes a command object and a hash of options,
    # it acts on the host's logger and connection object
    # it receives a result object from the connection#execute
    # (which it's really just a confusing wrapper for)
    # it controls the result objects logging and fails a test for TestCase
    #   if the exit_code doesn't match
    # it returns the result object
    it 'EXEC!'

    # it takes a location and a destination
    # it basically proxies that to the connection object
    it 'do_scp_to logs info and proxies to the connection' do
      logger = mock(:logger)
      conn = mock(:connection)
      @options = { :logger => logger }
      host.instance_variable_set :@connection, conn
      args = [ 'source', 'target', {} ]

      logger.should_receive(:debug)
      conn.should_receive(:scp_to).with(*args, nil)

      host.do_scp_to *args
    end

    it 'do_scp_from logs info and proxies to the connection' do
      logger = mock(:logger)
      conn = mock(:connection)
      @options = { :logger => logger }
      host.instance_variable_set :@connection, conn
      args = [ 'source', 'target', {} ]

      logger.should_receive(:debug)
      conn.should_receive(:scp_from).with(*args, nil)

      host.do_scp_from *args
    end
    it 'interpolates to its "name"' do
      expect( "#{host}" ).to be === 'name'
    end


    context 'merging defaults' do
      it 'knows the difference between foss and pe' do
        @options = {:type => :pe}
        expect( host['puppetpath'] ).to be === '/etc/puppetlabs/puppet'
      end

    end
  end
end
