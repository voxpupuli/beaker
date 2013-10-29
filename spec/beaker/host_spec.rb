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
      expect { host['value'] }.to_not raise_error NoMethodError
    end

    it 'can be written like a hash' do
      host['value'] = 'blarg'
      expect( host['value'] ).to be === 'blarg'
    end


    describe "executing commands" do
      let(:command) { Beaker::Command.new('ls') }
      let(:host) { Beaker::Host.create('host', make_host_opts('host', options.merge(platform))) }
      let(:result) { Beaker::Result.new(host, 'ls') }

      before :each do
        result.stdout = 'stdout'
        result.stderr = 'stderr'

        logger = mock(:logger)
        logger.stub(:host_output)
        logger.stub(:debug)
        host.instance_variable_set :@logger, logger
        conn = mock(:connection)
        conn.stub(:execute).and_return(result)
        host.instance_variable_set :@connection, conn
      end

      it 'takes a command object and a hash of options'
      it "acts on the host's logger and connection object"
      it 'receives a result object from the connection#execute'
      it "returns the result object"

      context "controls the result objects logging" do
        it "and passes a test if the exit_code doesn't match the default :acceptable_exit_codes of 0" do
          result.exit_code = 0
          expect { host.exec(command,{}) }.to_not raise_error
        end
        it "and fails a test if the exit_code doesn't match the default :acceptable_exit_codes of 0" do
          result.exit_code = 1
          expect { host.exec(command,{}) }.to raise_error
        end
        it "and passes a test if the exit_code matches :acceptable_exit_codes" do
          result.exit_code = 0
          expect { host.exec(command,{:acceptable_exit_codes => 0}) }.to_not raise_error
        end
        it "and fails a test if the exit_code doesn't match :acceptable_exit_codes" do
          result.exit_code = 0
          expect { host.exec(command,{:acceptable_exit_codes => 1}) }.to raise_error
        end
        it "and passes a test if the exit_code matches one of the :acceptable_exit_codes" do
          result.exit_code = 127
          expect { host.exec(command,{:acceptable_exit_codes => [1,127]}) }.to_not raise_error
        end
        it "and passes a test if the exit_code matches one of the range of :acceptable_exit_codes" do
          result.exit_code = 1
          expect { host.exec(command,{:acceptable_exit_codes => (0..127)}) }.to_not raise_error
        end
      end
    end

    # it takes a location and a destination
    # it basically proxies that to the connection object
    it 'do_scp_to logs info and proxies to the connection' do
      logger = host[:logger]
      conn = mock(:connection)
      @options = { :logger => logger }
      host.instance_variable_set :@connection, conn
      args = [ 'source', 'target', {} ]

      logger.should_receive(:debug)
      conn.should_receive(:scp_to).with(*args, $dry_run)

      host.do_scp_to *args
    end

    it 'do_scp_from logs info and proxies to the connection' do
      logger = host[:logger]
      conn = mock(:connection)
      @options = { :logger => logger }
      host.instance_variable_set :@connection, conn
      args = [ 'source', 'target', {} ]

      logger.should_receive(:debug)
      conn.should_receive(:scp_from).with(*args, $dry_run)

      host.do_scp_from *args
    end
    it 'interpolates to its "name"' do
      expect( "#{host}" ).to be === 'name'
    end


    context 'merging defaults' do
      it 'knows the difference between foss and pe' do
        @options = { :type => :pe }
        expect( host['puppetpath'] ).to be === '/etc/puppetlabs/puppet'
      end

    end
  end
end
