class TestWrapper
  class Host
    # A cache for active SSH connections to our execution nodes.
    @@ssh = {}

    def initialize(name, overrides, defaults)
      @name,@overrides,@defaults = name,overrides,defaults
    end
    def []=(k,v)
      @overrides[k] = v
    end
    def [](k)
      @overrides.has_key?(k) ? @overrides[k] : @defaults[k]
    end
    def to_str
      @name
    end
    def to_s
      @name
    end

    # Wrap up the SSH connection process; this will cache the connection and
    # allow us to reuse it for each operation without needing to reauth every
    # single time.
    def ssh
      @@ssh[@name] ||= Net::SSH.start(@name, "root", @defaults['ssh'])
    end

    def exec (command)
      ssh.open_channel do |channel|
        channel.exec(command) do |terminal, success|
          abort "FAILED: to execute command on a new channel on #{@name}" unless success
          yield terminal
        end
      end
      # Process SSH activity until we stop doing that - which is when our
      # channel is finished with...
      ssh.loop
    end

    def scp
      # This just makes available an scp channel available on the current login.
      scp = ssh.scp
      yield scp if block_given?
      scp
    end
  end

  attr_reader :config, :path, :fail_flag, :usr_home
  def initialize(config,path=nil)
    @config = config['CONFIG']
    @hosts  = config['HOSTS'].collect { |name,overrides| Host.new(name,overrides,@config) }
    @path = path
    @fail_flag = 0
    @usr_home = ENV['HOME']
    #
    # We put this on each wrapper (rather than the class) so that methods
    # defined in the tests don't leak out to other tests. 
    class << self
      def run_test
        test = File.read(path)
        eval test,nil,path,1
        classes = test.split(/\n/).collect { |l| l[/^ *class +(\w+) *$/,1]}.compact
        case classes.length
        when 0; self
        when 1; eval(classes[0]).new(config)
        else fail "More than one class found in #{path}"
        end
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
  attr_reader :step_name
  def step(lable,description=lable)
    @step_name = description
    @step_lable = lable
  end
  def test_name(name)
    step name
  end
  #
  # Basic operations
  #
  attr_reader :result
  def on(host,command,options={},&block)
    if host.is_a? Array
      host.each { |h| on h, command, options, &block }
    elsif command.is_a? Array
      command.each { |cmd| on host, cmd, options, &block }
    else
      BeginTest.new(host, step_name) unless options[:silent]
      runner = RemoteExec.new(host)
      @result = runner.do_remote(command, options[:stdin])
      if block_given? then
        yield                   # ...and delegate checking to the caller
      else
        result.log(step_name) unless options[:silent]
        @fail_flag+=result.exit_code unless options[:silent]
      end
    end
  end
  def scp_to(host,from_path,to_path,options={})
    if host.is_a? Array
      host.each { |h| scp_to h,from_path,to_path,options }
    else
      BeginTest.new(host, step_name)
      scper = ScpFile.new(host)
      @result = scper.do_scp(from_path, to_path)
      result.log(step_name)
      @fail_flag+=result.exit_code
    end
  end
  def pass_test(msg)
    puts msg
  end
  def fail_test(msg)
    puts msg
    @fail_flag += 1
  end
  #
  # result access
  #
  def stdout
    result.stdout
  end
  def stderr
    result.stderr
  end
  def exit_code
    result.exit_code
  end
  #
  # Macros
  #
  def with_env(*args)
    lib  = [config['puppet'] + '/lib', config['facter'] + '/lib'].join(':')
    path = [config['puppet'] + '/bin', config['facter'] + '/bin'].join(':') + ':$PATH'
    env  = "env RUBYLIB=\"#{lib}\" PATH=\"#{path}\""

    cmd = "#{env} #{args.join(' ')}"
    return cmd
  end

  def facter(host, *args)
    on host, with_env('facter', *args)
  end

  def puppet(host, action, *extra, &block)
    args    = ["--vardir=/tmp", "--confdir=/tmp", "--ssldir=/tmp"]
    options = {}
    while extra.length > 0 do
      if extra[0].is_a? Symbol then
        options[ extra.shift ] = extra.shift
      elsif extra[0].is_a? Hash then
        options.merge!(extra.shift)
      else
        args << extra.shift
      end
    end

    on(host, with_env("puppet", action.to_s, *args), options, &block)
  end

  def run_manifest(host,manifest,*extra,&block)
    puppet(host, :apply, "--verbose",
           :stdin => manifest + "\n", *extra, &block)
  end

  def run_agent_on(host,options='--no-daemonize --verbose --onetime --test')
    if host.is_a? Array
      host.each { |h| run_agent_on h }
    elsif "ticket #5541 is a pain and hasn't been fixed"
      BeginTest.new(host, step_name) unless options[:silent]
      2.times { on host,"puppet agent #{options}",:silent => true }
      result.log(step_name) unless options[:silent]
      @fail_flag+=result.exit_code unless options[:silent]
    else
      on host,"puppet agent #{options}"
    end
  end
  def prep_nodes
    step "Copy ptest.tgz executables to all hosts"
    scp_to hosts,"#{$work_dir}/dist/ptest.tgz", "/"

    step "Untar ptest.tgz executables to all hosts"
    on hosts,"cd / && tar xzf ptest.tgz"

    step "Copy puppet.tgz code to Master"
    scp_to master,"#{$work_dir}/dist/puppet.tgz", "/etc/puppetlabs"

    step "Set filetimeout= 0 in puppet.conf"
    on master,"cd /etc/puppetlabs/puppet; (grep filetimeout puppet.conf > /dev/null 2>&1) || sed -i \'s/\\[master\\]/\\[master\\]\\n    filetimeout = 0\/\' puppet.conf"

    step "Untar Puppet code on Master"
    on master,"cd /etc/puppetlabs && tar xzf puppet.tgz"
  end
  def clean_hosts
    step "Clean Hosts"
    on hosts,"rpm -qa | grep puppet | xargs rpm -e; rpm -qa | grep pe- | xargs rpm -e; rm -rf puppet-enterprise*; rm -rf /etc/puppetlabs"
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
end
