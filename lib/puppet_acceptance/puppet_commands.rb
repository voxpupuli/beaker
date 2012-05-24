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
    # [&block] this method will yield to a block of code passed by the caller; this can be used for additional validation,
    #     etc.
    def apply_manifest_on(host,manifest,options={},&block)
      on_options = {:stdin => manifest + "\n"}
      on_options[:acceptable_exit_codes] = options.delete(:acceptable_exit_codes) if options.keys.include?(:acceptable_exit_codes)
      args = ["--verbose"]
      args << "--parseonly" if options[:parseonly]
      args << "--trace" if options[:trace]

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
  end
end
