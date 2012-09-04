module PuppetAcceptance
  module PuppetCommands

    def facter(*args)
      FacterCommand.new(*args)
    end

    def puppet(*args)
      PuppetCommand.new(*args)
    end

    def hiera(*args)
      HieraCommand.new(*args)
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
    #   :trace => any value.  If this key exists in the Hash, the "--trace" command line parameter will be
    #     passed to the 'puppet apply' command.
    #   :environment => a Hash containing string->string key value pairs.  These will be treated as extra environment
    #     variables that should be set before running the puppet command.
    #   :catch_failures => boolean. By default "puppet --apply" will exit with 0, which does not count as a test
    #     failure, even if there were errors applying the manifest. This option enables detailed exit codes and causes
    #     a test failure if "puppet --apply" indicates there was a failure during its execution.
    # [&block] this method will yield to a block of code passed by the caller; this can be used for additional validation,
    #     etc.
    def apply_manifest_on(host, manifest, options={}, &block)
      on_options = {:stdin => manifest + "\n"}
      on_options[:acceptable_exit_codes] = options.delete(:acceptable_exit_codes) if options.keys.include?(:acceptable_exit_codes)
      args = ["--verbose"]
      args << "--parseonly" if options[:parseonly]
      args << "--trace" if options[:trace]

      if options[:catch_failures]
        args << '--detailed-exitcodes'

        # From puppet help:
        # "... an exit code of '2' means there were changes, an exit code of '4' means there were
        # failures during the transaction, and an exit code of '6' means there were both
        # changes and failures."
        # We're after failures specifically so catch exit codes 4 and 6 only.
        on_options[:acceptable_exit_codes] = [0, 2]
      end

      # Not really thrilled with this implementation, might want to improve it later.  Basically, there is a magic
      # trick in the constructor of PuppetCommand which allows you to pass in a Hash for the last value in the *args
      # Array; if you do so, it will be treated specially.  So, here we check to see if our caller passed us a hash
      # of environment variables that they want to set for the puppet command.  If so, we set the final value of
      # *args to a new hash with just one entry (the value of which is our environment variables hash)
      args << { :environment => options[:environment]} if options.has_key?(:environment)

      on host, puppet_apply(*args), on_options, &block
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
    # * --dns_alt_names="puppet, $(facter hostname), $(puppet fqdn)"
    def with_master_running_on(host, args='--daemonize', options={}, &block)
      # they probably want to run with daemonize.  If they pass some other arg/args but forget to re-include
      # daemonize, we'll check and make sure they didn't explicitly specify "no-daemonize", and, failing that,
      # we'll add daemonize to the args string
      if (args !~ /(?:--daemonize)|(?:--no-daemonize)/) then args << " --daemonize" end

      if (args !~ /--logdest/) then args << " --logdest=\"#{master['puppetvardir']}/log/puppetmaster.log\"" end
      if (args !~ /--dns_alt_names/) then args << " --dns_alt_names=\"puppet, $(facter hostname), $(facter fqdn)\"" end

      on hosts, host_command('rm -rf #{host["puppetpath"]}/ssl') unless options[:preserve_ssl]
      agents.each do |agent|
        if vardir = agent['puppetvardir']
          # we want to remove everything except the log and ssl directory (we
          # just got rid of ssl if preserve_ssl wasn't set, and otherwise want
          # to leave it)
          on agent, %Q[for i in "#{vardir}/*"; do echo $i; done | grep -v log| grep -v ssl | xargs rm -rf]
        end
      end

      on host, puppet_master('--configprint pidfile')

      pidfile = stdout.chomp

      start_puppet_master(host, args, pidfile)

      yield if block
    ensure
      stop_puppet_master(host, pidfile)
    end

    def start_puppet_master(host, args, pidfile)
      on host, puppet_master(args)
      on(host, "kill -0 $(cat #{pidfile})", :acceptable_exit_codes => [0,1])

      raise "Puppet master doesn't appear to be running at all" unless exit_code == 0

      timeout = 15
      wait_start = Time.now

      @logger.debug "Waiting for master to start"

      begin
        Timeout.timeout(timeout) do
          loop do
            # 7 is "Could not connect to host", which will happen before it's running
            result = on(host, "curl -s -k https://#{host}:8140", :acceptable_exit_codes => [0,7])
            break if exit_code == 0
            sleep 1
          end
        end
      rescue Timeout::Error
        raise "Puppet master failed to start after #{timeout} seconds"
      end

      wait_finish = Time.now
      elapsed = wait_finish - wait_start

      @logger.debug "Slept for #{elapsed} seconds waiting for Puppet Master to start"
    end

    def stop_puppet_master(host, pidfile)
      on host, "[ -f #{pidfile} ]", :silent => true

      raise "Could not locate running puppet master" unless exit_code == 0

      on host, "kill $(cat #{pidfile})", :acceptable_exit_codes => [0,1]

      timeout = 10
      wait_start = Time.now

      @logger.debug "Waiting for master to stop"

      begin
        Timeout.timeout(timeout) do
          loop do
            on(host, "kill -0 $(cat #{pidfile})", :acceptable_exit_codes => [0,1])
            break if exit_code == 1
            sleep 1
          end
        end
      rescue Timeout::Error
        elapsed = Time.now - wait_start
        @logger.warn "Puppet master failed to stop after #{elapsed} seconds; killing manually"
        on host, "kill -9 $(cat #{pidfile})"
        on host, "rm -f #{pidfile}"
      end

      wait_finish = Time.now
      elapsed = wait_finish - wait_start

      @logger.debug "Slept for #{elapsed} seconds waiting for Puppet Master to stop"
    end
  end
end
