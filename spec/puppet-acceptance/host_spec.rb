require 'spec_helper'

module PuppetAcceptance
  describe Host do
    let :config do
      MockConfig.new({}, {'name' => {'platform' => @platform}}, @pe)
    end

    let(:options) { @options || Hash.new                  }
    let(:host)    { Host.create 'name', options, config   }

    it 'creates a windows host given a windows config' do
      @platform = 'windows'
      expect( host ).to be_a_kind_of Windows::Host
    end

    it( 'defaults to a unix host' ) { expect( host ).to be_a_kind_of Unix::Host }

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
      conn.should_receive(:scp_to).with(*args)

      host.do_scp_to *args
    end

    it 'do_scp_from logs info and proxies to the connection' do
      logger = mock(:logger)
      conn = mock(:connection)
      @options = { :logger => logger }
      host.instance_variable_set :@connection, conn
      args = [ 'source', 'target', {} ]

      logger.should_receive(:debug)
      conn.should_receive(:scp_from).with(*args)

      host.do_scp_from *args
    end
    it 'interpolates to its "name"' do
      expect( "#{host}" ).to be === 'name'
    end


    context 'merging defaults' do
      it 'knows the difference between foss and pe' do
        @pe = true
        expect( host['puppetpath'] ).to be === '/etc/puppetlabs/puppet'
      end

      it 'correctly merges network configs over defaults?' do
        overridden_config = MockConfig.new( {'puppetpath'=> '/i/do/what/i/want'},
                                            {'name' => {} },
                                              false )
        merged_host = Host.create 'name', options, overridden_config
        expect( merged_host['puppetpath'] ).to be === '/i/do/what/i/want'
      end

      it 'correctly merges host specifics over defaults' do
        overriding_config = MockConfig.new( {},
                                            {'name' => {
                                              'puppetpath' => '/utter/awesomeness'}
                                            }, true )

        merged_host = Host.create 'name', options, overriding_config
        expect( merged_host['puppetpath'] ).to be === '/utter/awesomeness'
      end
    end
  end
end
