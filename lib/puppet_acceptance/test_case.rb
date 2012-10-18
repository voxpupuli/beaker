module PuppetAcceptance
  class TestCase
    require File.expand_path(File.join(File.dirname(__FILE__), 'host'))
    require File.expand_path(File.join(File.dirname(__FILE__), 'assertions'))
    require File.expand_path(File.join(File.dirname(__FILE__), 'puppet_commands'))
    require File.expand_path(File.join(File.dirname(__FILE__), 'helpers'))
    require 'tempfile'
    require 'benchmark'
    require 'stringio'

    include Assertions
    include PuppetCommands
    include Helpers

    class PendingTest < Exception; end
    class SkipTest < Exception; end

    attr_reader :version, :config, :logger, :options, :path, :fail_flag, :usr_home,
                :test_status, :exception, :runtime, :teardown_procs, :result

    def initialize(hosts, logger, config, options={}, path=nil)
      @version = config['VERSION']
      @config  = config['CONFIG']
      @hosts   = hosts
      @logger = logger
      @options = options
      @path    = path
      @usr_home = ENV['HOME']
      @test_status = :pass
      @exception = nil
      @runtime = nil
      @teardown_procs = []
      #
      # We put this on each wrapper (rather than the class) so that methods
      # defined in the tests don't leak out to other tests.
      class << self
        def run_test
          @runtime = Benchmark.realtime do
            begin
              test = File.read(path)
              eval test,nil,path,1
            rescue Test::Unit::AssertionFailedError => e
              @test_status = :fail
              @exception   = e
            rescue PendingTest
              @test_status = :pending
            rescue SkipTest
              @test_status = :skip
            rescue StandardError, ScriptError => e
              log_and_fail_test(e)
            ensure
              @teardown_procs.each do |teardown|
                begin
                  teardown.call
                rescue StandardError => e
                  log_and_fail_test(e)
                end
              end
            end
          end
          return self
        end

        private

        # Log an error and mark the test as failed, passing through an
        # exception so it can be displayed at the end of the total run.
        #
        # We break out the complete exception backtrace and log each line
        # individually as well.
        #
        # @param exception [Exception] exception to fail with
        def log_and_fail_test(exception)
          @logger.error(exception.inspect)
          bt = exception.backtrace
          @logger.pretty_backtrace(bt).each_line do |line|
            @logger.error(line)
          end
          @test_status = :error
          @exception   = exception
        end
      end
    end

    def to_hash
      hash = {}
      hash['HOSTS'] = {}
      hash['CONFIG'] = @config
      @hosts.each do |host|
        hash['HOSTS'][host.name] = host.overrides
      end
      hash
    end

    #
    # Test Structure
    #
    def step(step_name, &block)
      @logger.notify "\n  * #{step_name}\n"
      yield if block
    end

    def test_name(test_name, &block)
      @logger.notify "\n#{test_name}\n"
      yield if block
    end

    def pass_test(msg)
      @logger.notify "\n#{msg}\n"
    end

    def skip_test(msg)
      @logger.notify "Skip: #{msg}\n"
      raise SkipTest
    end

    def fail_test(msg)
      flunk(msg + "\n" + @logger.pretty_backtrace() + "\n")
    end

    def pending_test(msg = "WIP: #{@test_name}")
      @logger.warn msg
      raise PendingTest
    end

    def confine(type, confines)
      confines.each_pair do |property, value|
        case type
        when :except
          @hosts = @hosts.reject do |host|
            inspect_host host, property, value
          end
        when :to
          @hosts = @hosts.select do |host|
            inspect_host host, property, value
          end
        else
          raise "Unknown option #{type}"
        end
      end
      if @hosts.empty?
        @logger.warn "No suitable hosts with: #{confines.inspect}"
        skip_test 'No suitable hosts found'
      end
    end

    def inspect_host(host, property, value)
      true_false = false
      case value
      when String
        true_false = host[property.to_s].include? value
      when Regexp
        true_false = host[property.to_s] =~ value
      end
      true_false
    end

    # Declare a teardown process that will be called after a test case is
    # complete.
    #
    # @param block [Proc] block of code to execute during teardown
    # @example Always remove /etc/puppet/modules
    #   teardown do
    #     on(master, puppet_resource('file', '/etc/puppet/modules',
    #       'ensure=absent', 'purge=true'))
    #   end
    def teardown(&block)
      @teardown_procs << block
    end

    #
    # result access
    #
    def stdout
      return nil if @result.nil?
      @result.stdout
    end

    def stderr
      return nil if @result.nil?
      @result.stderr
    end

    def exit_code
      return nil if @result.nil?
      @result.exit_code
    end

    #
    # Networking Helpers
    #
    def on(host, command, options={}, &block)
      if command.is_a? String
        command = Command.new(command)
      end
      if host.is_a? Array
        host.map { |h| on h, command, options, &block }
      else
        @result = host.exec(command, options)

        # Also, let additional checking be performed by the caller.
        yield if block_given?

        return @result
      end
    end

    def scp_from(host, from_path, to_path, options={})
      if host.is_a? Array
        host.each { |h| scp_from h, from_path, to_path, options }
      else
        @result = host.do_scp_from(from_path, to_path)
        @result.log(@logger)
        raise "scp exited with #{@result.exit_code}" if @result.exit_code != 0
      end
    end

    def scp_to(host, from_path, to_path, options={})
      if host.is_a? Array
        host.each { |h| scp_to h, from_path, to_path, options }
      else
        @result = host.do_scp_to(from_path, to_path)
        @result.log(@logger)
        raise "scp exited with #{@result.exit_code}" if @result.exit_code != 0
      end
    end

    def create_remote_file(hosts, file_path, file_content)
      Tempfile.open 'puppet-acceptance' do |tempfile|
        File.open(tempfile.path, 'w') { |file| file.puts file_content }

        scp_to hosts, tempfile.path, file_path
      end
    end

    def run_script_on(host, script, &block)
      remote_path = File.join("", "tmp", File.basename(script))
      scp_to host, script, remote_path
      on host, remote_path, &block
    end

    #
    # Identify hosts
    #
    def hosts(desired_role = nil)
      @hosts.select do |host|
        desired_role.nil? or host['roles'].include?(desired_role)
      end
    end

    def agents
      hosts 'agent'
    end

    def master
      masters = hosts 'master'
      fail "There must be exactly one master" unless masters.length == 1
      masters.first
    end

    def database
      databases = hosts 'database'
      @logger.warn "There is no database host configured" if databases.empty?
      fail "Cannot have more than one database host" if databases.length > 1
      databases.first
    end

    def dashboard
      dashboards = hosts 'dashboard'
      @logger.warn "There is no dashboard host configured" if dashboards.empty?
      fail "Cannot have more than one dashboard host" if dashboards.length > 1
      dashboards.first
    end

    # This method retrieves the forge hostname from either:
    # * The environment variable 'forge_host'
    # * The parameter 'forge_host' from the CONFIG hash in a node definition
    #
    # If none of these are available, it falls back to the static
    # 'forge-acceptance.puppetlabs.lan'
    #
    # @return [String] hostname of test forge
    def forge
      ENV['forge_host'] || @config['forge_host'] || 'forge-acceptance.puppetlabs.lan'
    end
  end
end
