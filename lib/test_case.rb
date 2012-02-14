class TestCase
  require 'lib/host'
  require 'tempfile'
  require 'benchmark'
  require 'stringio'

  include Test::Unit::Assertions

  attr_reader :version, :config, :options, :path, :fail_flag, :usr_home, :test_status, :exception
  attr_reader :runtime
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
    Log.warn "There is no dashboard host configured" if dashboards.empty?
    fail "Cannot have more than one dashboard host" if dashboards.length > 1
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
    flunk(msg + "\n" + Log.pretty_backtrace() + "\n")
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

  def puppet(*args)
    PuppetCommand.new(*args)
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

  def host_command(command_string)
    HostCommand.new(command_string)
  end

  # method apply_manifest_on
  # runs a 'puppet apply' command on a remote host
  # parameters:
  # [host] an instance of Host which contains the info about the host that this command should be run on
  # [manifest] a string containing a puppet manifest to apply
  # [options] an optional hash containing options; legal values include:
  #   :acceptable_exit_codes => an array of integer exit codes that should be considered acceptable.  an error will be
  #     thrown if the exit code does not match one of the values in this list.
  #   :parseonly => any value.  If this key exists in the Hash, the "--parseonly" command line parameter will be
  #     passed to the 'puppet apply' command.
  #   :environment => a Hash containing string->string key value pairs.  These will be treated as extra environment
  #     variables that should be set before running the puppet command.
  # [&block] this method will yield to a block of code passed by the caller; this can be used for additional validation,
  #     etc.
  def apply_manifest_on(host,manifest,options={},&block)
    on_options = {:stdin => manifest + "\n"}
    on_options[:acceptable_exit_codes] = options.delete(:acceptable_exit_codes) if options.keys.include?(:acceptable_exit_codes)
    args = ["--verbose"]
    args << "--parseonly" if options[:parseonly]

    # Not really thrilled with this implementation, might want to improve it later.  Basically, there is a magic
    # trick in the constructor of PuppetCommand which allows you to pass in a Hash for the last value in the *args
    # Array; if you do so, it will be treated specially.  So, here we check to see if our caller passed us a hash
    # of environment variables that they want to set for the puppet command.  If so, we set the final value of
    # *args to a new hash with just one entry (the value of which is our environment variables hash)
    args << { :environment => options[:environment]} if options.has_key?(:environment)

    on host, puppet_apply(*args), on_options, &block
  end

  def run_script_on(host, script, &block)
    remote_path=File.join("", "tmp", File.basename(script))
    scp_to host, script, remote_path
    on host, remote_path, &block
  end

  def run_agent_on(host, arg='--no-daemonize --verbose --onetime --test', options={}, &block)
    if host.is_a? Array
      host.each { |h| run_agent_on h, arg, options, &block }
    else
      on host, puppet_agent(arg), options, &block
    end
  end

  def run_cron_on(host, action, user, entry="", &block)
    platform = host['platform']
    if platform.include? 'solaris'
      case action
        when :list   then args = '-l'
        when :remove then args = '-r'
        when :add
          on(host, "echo '#{entry}' > /var/spool/cron/crontabs/#{user}", &block)
      end
    else         # default for GNU/Linux platforms
      case action
        when :list   then args = '-l -u'
        when :remove then args = '-r -u'
        when :add
           on(host, "echo '#{entry}' > /tmp/#{user}.cron && crontab -u #{user} /tmp/#{user}.cron", &block)
      end
    end
   
    if args
      case action
        when :list, :remove then on(host, "crontab #{args} #{user}", &block)
      end
    end
  end

  # This method performs the following steps:
  # 1. issues start command for puppet master on specified host
  # 2. polls until it determines that the master has started successfully
  # 3. yields to a block of code passed by the caller
  # 4. runs a "kill" command on the master's pid (on the specified host)
  # 5. polls until it determines that the master has shut down successfully.
  #
  # Parameters:
  # [host] the master host
  # [arg] a string containing all of the command line arguments that you would like for the puppet master to
  #     be started with.  Defaults to '--daemonize'.  NOTE: the following values will be added to the argument list
  #     if they are not explicitly set in your 'args' parameter:
  # * --daemonize
  # * --logdest="#{host['puppetvardir']}/log/puppetmaster.log"
  # * --dns_alt_names="puppet, $(hostname -s), $(hostname -f)"
  def with_master_running_on(host, arg='--daemonize', &block)
    # they probably want to run with daemonize.  If they pass some other arg/args but forget to re-include
    # daemonize, we'll check and make sure they didn't explicitly specify "no-daemonize", and, failing that,
    # we'll add daemonize to the arg string
    if (arg !~ /(?:--daemonize)|(?:--no-daemonize)/) then arg << " --daemonize" end

    if (arg !~ /--logdest/) then arg << " --logdest=\"#{master['puppetvardir']}/log/puppetmaster.log\"" end
    if (arg !~ /--dns_alt_names/) then arg << " --dns_alt_names=\"puppet, $(hostname -s), $(hostname -f)\"" end

    on hosts, host_command('rm -rf #{host["puppetpath"]}/ssl')
    agents.each do |agent|
      if vardir = agent['puppetvardir']
        # we want to remove everything except the log directory
        on agent, "if [ -e \"#{vardir}\" ]; then for f in #{vardir}/*; do if [ \"$f\" != \"#{vardir}/log\" ]; then rm -rf \"$f\"; fi; done; fi"
      end
    end

    on host, puppet_master('--configprint pidfile')
    pidfile = stdout.chomp
    on host, puppet_master(arg)
    poll_master_until(host, :start)
    master_started = true
    yield if block
  ensure
    if master_started
      on host, "kill $(cat #{pidfile})"
      poll_master_until(host, :stop)
    end
  end

  def poll_master_until(host, verb)
    timeout = 30
    verb_exit_codes = {:start => 0, :stop => 7}

    Log.debug "Wait for master to #{verb}"

    agent = agents.first
    wait_start = Time.now
    done = false

    until done or Time.now - wait_start > timeout
      on(agent, "curl -k https://#{master}:8140 >& /dev/null", :acceptable_exit_codes => (0..255))
      done = exit_code == verb_exit_codes[verb]
      sleep 1 unless done
    end

    wait_finish = Time.now
    elapsed = wait_finish - wait_start

    if done
      Log.debug "Slept for #{elapsed} seconds waiting for Puppet Master to #{verb}"
    else
      Log.error "Puppet Master failed to #{verb} after #{elapsed} seconds"
    end
  end

  def create_remote_file(hosts, file_path, file_content)
    Tempfile.open 'puppet-acceptance' do |tempfile|
      File.open(tempfile.path, 'w') { |file| file.puts file_content }

      scp_to hosts, tempfile.path, file_path
    end
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
