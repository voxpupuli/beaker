class TestWrapper
  class Host
    # A cache for active SSH connections to our execution nodes.
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
    def +(other)
      @name+other
    end

    def puppet_env
      %Q{env RUBYLIB="#{self['puppetlibdir']||''}:#{self['facterlibdir']||''}" PATH="#{self['puppetbindir']||''}:#{self['facterbindir']||''}:$PATH"}
    end

    # Wrap up the SSH connection process; this will cache the connection and
    # allow us to reuse it for each operation without needing to reauth every
    # single time.
    def ssh
      @ssh ||= Net::SSH.start(self, self['user'] || "root" , self['ssh'])
    end

    def do_action(verb,*args)
      result = Result.new(self,args,'','',0)
      puts "#{self}: #{verb}(#{args.inspect})"
      yield result unless $dry_run
      result
    end

    def exec(command, stdin)
      do_action('RemoteExec',command) { |result|
        ssh.open_channel do |channel|
          channel.exec(command) do |terminal, success|
            abort "FAILED: to execute command on a new channel on #{@name}" unless success
            terminal.on_data                   { |ch, data|       result.stdout << data }
            terminal.on_extended_data          { |ch, type, data| result.stderr << data if type == 1 }
            terminal.on_request("exit-status") { |ch, data|       result.exit_code = data.read_long  }

            # queue stdin data, force it to packets, and signal eof: this
            # triggers action in many remote commands, notably including
            # 'puppet apply'.  It must be sent at some point before the rest
            # of the action.
            terminal.send_data(stdin.to_s)
            terminal.process
            terminal.eof!
          end
        end
        # Process SSH activity until we stop doing that - which is when our
        # channel is finished with...
        ssh.loop
      }
    end

    def do_scp(source, target)
      do_action("ScpFile",source,target) { |result|
        # Net::Scp always returns 0, so just set the return code to 0 Setting
        # these values allows reporting via result.log(test_name)
        result.stdout = "SCP'ed file #{source} to #{@host}:#{target}"
        result.stderr=nil
        result.exit_code=0
        ssh.scp.upload!(source, target)
      }
    end
  end

  attr_reader :config, :options, :path, :fail_flag, :usr_home
  def initialize(config,options,path=nil)
    @config  = config['CONFIG']
    @hosts   = config['HOSTS'].collect { |name,overrides| Host.new(name,overrides,@config) }
    @options = options
    @path    = path
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
  def on(host, command, options={}, &block)
    if command.is_a? String
      command = Command.new(command)
    end
    if host.is_a? Array
      host.each { |h| on h, command, options, &block }
    elsif command.is_a? Array
      command.each { |cmd| on host, cmd, options, &block }
    else
      BeginTest.new(host, step_name) unless options[:silent]

      @result = host.exec(command.cmd_line(host), options[:stdin])

      unless options[:silent] then
        result.log(step_name)
        @fail_flag += 1 unless (options[:acceptable_exit_codes] || [0]).include?(exit_code)
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
      BeginTest.new(host, step_name)
      @result = host.do_scp(from_path, to_path)
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

  def apply_manifest_on(host,manifest,options={},&block)
    on_options = {:stdin => manifest + "\n"}
    on_options[:acceptable_exit_codes] = options.delete(:acceptable_exit_codes) if options.keys.include?(:acceptable_exit_codes)
    args = ["--verbose"]
    args << "--parseonly" if options[:parseonly]
    on host, puppet_apply(*args), on_options, &block
  end

  def run_agent_on(host,arg='--no-daemonize --verbose --onetime --test')
    if host.is_a? Array
      host.each { |h| run_agent_on h }
    elsif "ticket #5541 is a pain and hasn't been fixed"
      BeginTest.new(host, step_name)
      2.times { on host,puppet_agent(arg),:silent => true }
      result.log(step_name)
      @fail_flag+=result.exit_code
    else
      on host,puppet_agent(arg)
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
