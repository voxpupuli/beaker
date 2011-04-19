class TestCase
  require 'lib/test_case/host'
  require 'tempfile'
  require 'benchmark'
  require 'stringio'

  include Test::Unit::Assertions

  attr_reader :config, :options, :path, :fail_flag, :usr_home, :test_status, :exception
  attr_reader :runtime
  def initialize(config, options={}, path=nil)
    @config  = config['CONFIG']
    @hosts   = config['HOSTS'].collect { |name,overrides| Host.new(name,overrides,@config) }
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
            rescue StandardError, ScriptError => e
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
  #
  # Identify hosts
  #
  def hosts(desired_role=nil)
    @hosts.select { |host| desired_role.nil? or host['roles'].include?(desired_role) }
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
    fail "There must be exactly one dashboard" unless dashboards.length == 1
    dashboards.first
  end
  #
  # Annotations
  #
  def step(step_name,&block)
    Log.notify "  * #{step_name}"
    yield if block
  end

  def test_name(test_name,&block)
    Log.notify test_name
    yield if block
  end
  #
  # Basic operations
  #
  attr_reader :result
  def on(host, command, options={}, &block)
    options[:acceptable_exit_codes] ||= [0]
    options[:failing_exit_codes]    ||= [1]
    if command.is_a? String
      command = Command.new(command)
    end
    if host.is_a? Array
      host.map { |h| on h, command, options, &block }
    else
      @result = command.exec(host, options)

      unless options[:silent] then
        result.log
        if options[:acceptable_exit_codes].include?(exit_code)
          # cool.
        elsif options[:failing_exit_codes].include?(exit_code)
          assert( false, "Exited with #{exit_code}" )
        else
          raise "Exited with #{exit_code}"
        end
      end

      # Also, let additional checking be performed by the caller.
      yield if block_given?

      return @result
    end
  end

  def scp_to(host,from_path,to_path,options={})
    if host.is_a? Array
      host.each { |h| scp_to h,from_path,to_path,options }
    else
      @result = host.do_scp(from_path, to_path)
      result.log
      raise "scp exited with #{result.exit_code}" if result.exit_code != 0
    end
  end

  def pass_test(msg)
    Log.notify msg
  end
  def skip_test(msg)
    Log.notify "Skip: #{msg}"
    @test_status = :skip
  end
  def fail_test(msg)
    assert(false, msg)
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
  # Macros
  #

  def facter(*args)
    FacterCommand.new(*args)
  end

  def puppet_resource(*args)
    PuppetCommand.new(:resource,*args)
  end

  def puppet_doc(*args)
    PuppetCommand.new(:doc,*args)
  end

  def puppet_kick(*args)
    PuppetCommand.new(:kick,*args)
  end

  def puppet_cert(*args)
    PuppetCommand.new(:cert,*args)
  end

  def puppet_apply(*args)
    PuppetCommand.new(:apply,*args)
  end

  def puppet_master(*args)
    PuppetCommand.new(:master,*args)
  end

  def puppet_agent(*args)
    PuppetCommand.new(:agent,*args)
  end

  def puppet_filebucket(*args)
    PuppetCommand.new(:filebucket,*args)
  end

  def apply_manifest_on(host,manifest,options={},&block)
    on_options = {:stdin => manifest + "\n"}
    on_options[:acceptable_exit_codes] = options.delete(:acceptable_exit_codes) if options.keys.include?(:acceptable_exit_codes)
    args = ["--verbose"]
    args << "--parseonly" if options[:parseonly]
    on host, puppet_apply(*args), on_options, &block
  end

  def run_script_on(host,script)
    remote_path=File.join("", "tmp", File.basename(script))
    scp_to hosts, script, remote_path
    on hosts, remote_path
  end

  def run_agent_on(host,arg='--no-daemonize --verbose --onetime --test')
    if host.is_a? Array
      host.each { |h| run_agent_on h }
    elsif ["ticket #5541 is a pain and hasn't been fixed"] # XXX
      2.times { on host,puppet_agent(arg),:silent => true }
      result.log
      raise "Error code from puppet agent" if result.exit_code != 0
    else
      on host,puppet_agent(arg)
    end
  end

  def create_remote_file(hosts, file_path, file_content)
    Tempfile.open 'puppet-acceptance' do |tempfile|
      File.open(tempfile.path, 'w') { |file| file.puts file_content }

      scp_to hosts, tempfile.path, file_path
    end
  end

  def get_remote_option(hosts, subcommand, option)
    on hosts, "puppet #{subcommand} --configprint #{option}" do
      yield stdout.chomp
    end
  end

  def prep_initpp(host, entry, path="/etc/puppetlabs/puppet/modules/puppet_system_test/manifests")
    # Rewrite the init.pp file with an additional class to test
    # eg: class puppet_system_test {
    #  include group
    #  include user
    #}
    step "Append new system_test_class to init.pp"
    # on host,"cd #{path} && head -n -1 init.pp > tmp_init.pp && echo include #{entry} >> tmp_init.pp && echo \} >> tmp_init.pp && mv -f tmp_init.pp init.pp"
    on host,"cd #{path} && echo class puppet_system_test \{ > init.pp && echo include #{entry} >> init.pp && echo \} >>init.pp"
  end


  def with_standard_output_to_logs
    stdout = ''
    old_stdout = $stdout
    $stdout = StringIO.new(stdout, 'w')

    stderr = ''
    old_stderr = $stderr
    $stderr = StringIO.new(stderr, 'w')

    result = yield

    $stdout = old_stdout
    $stderr = old_stderr

    stdout.each { |line| Log.notify(line) }
    stderr.each { |line| Log.warn(line) }

    return result
  end
end
