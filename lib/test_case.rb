class TestCase
  require 'lib/host'
  require 'tempfile'
  require 'benchmark'
  require 'stringio'
  require 'lib/puppet_commands'

  include Test::Unit::Assertions
  include PuppetCommands

  class PendingTest < Exception; end

  attr_reader :version, :config, :options, :path, :fail_flag, :usr_home,
              :test_status, :exception, :runtime, :result

  def initialize(hosts, config, options={}, path=nil)
    @version = config['VERSION']
    @config  = config['CONFIG']
    @hosts   = hosts
    @options = options
    @path    = path
    @usr_home = ENV['HOME']
    @test_status = :pass
    @exception = nil
    @runtime = nil
    #
    # We put this on each wrapper (rather than the class) so that methods
    # defined in the tests don't leak out to other tests.
    class << self
      def run_test
        with_standard_output_to_logs do
          @runtime = Benchmark.realtime do
            begin
              test = File.read(path)
              eval test,nil,path,1
            rescue Test::Unit::AssertionFailedError => e
              @test_status = :fail
              @exception   = e
            rescue PendingTest
              @test_status = :pending
            rescue StandardError, ScriptError => e
              Log.error(e.inspect)
              e.backtrace.each { |line| Log.error(line) }
              @test_status = :error
              @exception   = e
            end
          end
        end
        return self
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

  def with_standard_output_to_logs(&block)
    stdout = ''
    old_stdout = $stdout
    $stdout = StringIO.new(stdout, 'w')

    stderr = ''
    old_stderr = $stderr
    $stderr = StringIO.new(stderr, 'w')

    result = yield if block_given?

    $stdout = old_stdout
    $stderr = old_stderr

    stdout.each { |line| Log.notify(line) }
    stderr.each { |line| Log.warn(line) }

    return result
  end

  #
  # Test Structure
  #
  def step(step_name, &block)
    Log.notify "  * #{step_name}"
    yield if block
  end

  def test_name(test_name, &block)
    Log.notify test_name
    yield if block
  end

  def pass_test(msg)
    Log.notify msg
  end

  def skip_test(msg)
    Log.notify "Skip: #{msg}"
    @test_status = :skip
  end

  def fail_test(msg)
    flunk(msg + "\n" + Log.pretty_backtrace() + "\n")
  end

  def pending_test(msg = "WIP: #{@test_name}")
    Log.warn msg
    raise PendingTest
  end

  #
  # result access
  #
  def stdout
    return nil if result.nil?
    result.stdout
  end

  def stderr
    return nil if result.nil?
    result.stderr
  end

  def exit_code
    return nil if result.nil?
    result.exit_code
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
      @result = command.exec(host, options)

      # Also, let additional checking be performed by the caller.
      yield if block_given?

      return @result
    end
  end

  def scp_to(host, from_path, to_path, options={})
    if host.is_a? Array
      host.each { |h| scp_to h, from_path, to_path, options }
    else
      @result = host.do_scp(from_path, to_path)
      result.log
      raise "scp exited with #{result.exit_code}" if result.exit_code != 0
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

  def dashboard
    dashboards = hosts 'dashboard'
    Log.warn "There is no dashboard host configured" if dashboards.empty?
    fail "Cannot have more than one dashboard host" if dashboards.length > 1
    dashboards.first
  end
end
