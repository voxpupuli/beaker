module PuppetAcceptance
  # An immutable data structure representing a task to run on a remote
  # machine.
  class Command
    include Test::Unit::Assertions

    def initialize(command_string, options={})
      @command_string = command_string
      @options = options
    end

    # host_info is a hash-like object that can be queried to figure out
    # properties of the host.
    def cmd_line(host_info)
      @command_string
    end

    # Determine the appropriate puppet env command for the given host.
    # parameters:
    # [host_info] a Hash containing info about the host
    # [environment] an optional Hash containing key-value pairs to be treated as environment variables that should be
    #     set for the duration of the puppet command.
    def puppet_env_command(host_info, environment = {})
      rubylib = [
        host_info['hieralibdir'],
        host_info['hierapuppetlibdir'],
        host_info['pluginlibpath'],
        host_info['puppetlibdir'],
        host_info['facterlibdir'],
        '$RUBYLIB'
      ].compact.join(host_info['pathseparator'])

      # Always use colon for PATH, even Windows
      path = [
        host_info['puppetbindir'],
        host_info['facterbindir'],
        host_info['hierabindir'],
        '$PATH'
      ].compact.join(':')

      cmd = host_info['platform'] =~ /windows/ ? 'cmd.exe /c' : ''

      # if the caller passed in an "environment" hash, we need to build up a string of the form " KEY1=VAL1 KEY2=VAL2"
      # containing all of the specified environment vars.  We prefix it with a space because we will insert it into
      # the broader command below
      environment_vars_string = environment.nil? ? "" :
          " %s" % environment.collect { |key, val| "#{key}=#{val}" } .join(" ")

      # build up the actual command, prefixed with the RUBYLIB and PATH environment vars, plus our string containing
      # additional environment variables (which may be an empty string)
      %Q{env RUBYLIB="#{rubylib}" PATH="#{path}"#{environment_vars_string} #{cmd}}
    end
  end

  class PuppetCommand < Command
    def initialize(sub_command, *args)
      @sub_command = sub_command
      @options = args.last.is_a?(Hash) ? args.pop : {}

      # Not at all happy with this implementation, but it was the path of least resistance for the moment.
      # This constructor already does a little "magic" by allowing the final value in the *args Array to
      # be a Hash, which will be treated specially: popped from the regular args list and assigned to @options,
      # where it will later be used to add extra command line args to the puppet command (--key=value).
      #
      # Here we take this one step further--if the @options hash is passed in, we check and see if it has the
      # special key :environment in it.  If it does, then we'll pull that out of the options hash and treat
      # it specially too; we'll use it to set additional environment variables for the duration of the puppet
      # command.
      @environment = @options.has_key?(:environment) ? @options.delete(:environment) : nil
      # Dom: commenting these lines addressed bug #6920
      # @options[:vardir] ||= '/tmp'
      # @options[:confdir] ||= '/tmp'
      # @options[:ssldir] ||= '/tmp'
      @args = args
    end

    def cmd_line(host)
      args_string = (@args + @options.map { |key, value| "--#{key}=#{value}" }).join(' ')
      "#{puppet_env_command(host, @environment)} puppet #{@sub_command} #{args_string}"
    end
  end

  class FacterCommand < Command
    def initialize(*args)
      @args = args
    end

    def cmd_line(host)
      args_string = @args.join(' ')
      "#{puppet_env_command(host)} facter #{args_string}"
    end
  end

  class HieraCommand < Command
    def initialize(*args)
      @args = args
    end

    def cmd_line(host)
      args_string = @args.join(' ')
      "#{puppet_env_command(host)} hiera #{args_string}"
    end
  end

  class HostCommand < Command
    def cmd_line(host)
      eval "\"#{@command_string}\""
    end
  end
end
