module Beaker
  # An object that represents a "command" on a remote host. Is responsible
  # for munging the environment correctly. Probably poorly named.
  #
  # @api public
  class Command

    # A string representing the (possibly) incomplete command
    attr_accessor :command

    # A hash key-values where the keys are environment variables to be set
    attr_accessor :environment

    # A hash of options. Keys with values of nil are considered flags
    attr_accessor :options

    # An array of additional arguments to be supplied to the command
    attr_accessor :args

    # @param [String] command The program to call, either an absolute path
    #                         or one in the PATH (can be overridden)
    # @param [Array]  args    These are addition arguments to the command
    # @param [Hash]   options These are addition options to the command. They
    #                         will be added in "--key=value" after the command
    #                         but before the arguments. There is a special key,
    #                         'ENV', that won't be used as a command option,
    #                         but instead can be used to set any default
    #                         environment variables
    #
    # @example Recommended usage programmatically:
    #     Command.new('git add', files, :patch => true, 'ENV' => {'PATH' => '/opt/csw/bin'})
    #
    # @example My favorite example of a signature that we must maintain
    #     Command.new('puppet', :resource, 'scheduled_task', name,
    #                 [ 'ensure=present',
    #                   'command=c:\\\\windows\\\\system32\\\\notepad2.exe',
    #                   "arguments=args-#{name}" ] )
    #
    # @note For backwards compatability we must support any number of strings
    #       or symbols (or arrays of strings an symbols) and essentially
    #       ensure they are in a flattened array, coerced to strings, and
    #       call #join(' ') on it.  We have options for the command line
    #       invocation that must be turned into '--key=value' and similarly
    #       joined as well as a hash of environment key value pairs, and
    #       finally we need a hash of options to control the default envs that
    #       are included.
    def initialize command, args = [], options = {}
      @command = command
      @options = options
      @args    = args
      @environment = {}
      @cmdexe = @options.delete(:cmdexe) || false
      @prepend_cmds = @options.delete(:prepend_cmds) || nil

      # this is deprecated and will not allow you to use a command line
      # option of `--environment`, please use ENV instead.
      [:ENV, :environment, 'environment', 'ENV'].each do |k|
         if @options[k].is_a?(Hash)
           @environment = @environment.merge(@options.delete(k))
         end
      end

    end

    # @param [Host]   host An object that implements {Beaker::Host}'s
    #                      interface.
    # @param [String] cmd  An command to call.
    # @param [Hash]   env  An optional hash of environment variables to be used
    # @param [String] pc   An optional list of commands to prepend 
    #
    # @return [String] This returns the fully formed command line invocation.
    def cmd_line host, cmd = @command, env = @environment, pc = @prepend_cmds
      env_string = host.environment_string( env )
      prepend_commands = host.prepend_commands( cmd, pc, :cmd_exe => @cmdexe )
      if host[:platform] =~ /cisco/ && host[:user] != 'root'
        append_command = '"'
        cmd = cmd.gsub('"') { '\\"' }
      end

      # This will cause things like `puppet -t -v agent` which is maybe bad.
      if host[:platform] =~ /cisco_ios_xr/ 
        cmd_line_array = [prepend_commands, env_string, cmd, options_string, args_string]
      else
        cmd_line_array = [env_string, prepend_commands, cmd, options_string, args_string]
      end
      cmd_line_array << append_command unless (cmd =~ /ntpdate/ && host[:platform] =~ /cisco_nexus/)
      cmd_line_array.compact.reject( &:empty? ).join( ' ' )
    end

    # @param [Hash] opts These are the options that the command takes
    #
    # @return [String] String of the options and flags for command.
    #
    # @note Why no. Not the least bit Unixy, why do you ask?
    def options_string opts = @options
      flags = []
      options = opts.dup
      options.each_key do |key|
        if options[key] == nil
          flags << key
          options.delete(key)
        end
      end

      short_flags, long_flags = flags.partition {|flag| flag.to_s.length == 1 }
      parsed_short_flags = short_flags.map {|f| "-#{f}" }
      parsed_long_flags = long_flags.map {|f| "--#{f}" }

      short_opts, long_opts = {}, {}
      options.each_key do |key|
        if key.to_s.length == 1
          short_opts[key] = options[key]
        else
          long_opts[key] = options[key]
        end
      end
      parsed_short_opts = short_opts.map {|k,v| "-#{k}=#{v}" }
      parsed_long_opts = long_opts.map {|k,v| "--#{k}=#{v}" }

      return (parsed_short_flags +
              parsed_long_flags +
              parsed_short_opts + parsed_long_opts).join(' ')
    end

    # @param [Array] args An array of arguments to the command.
    #
    # @return [String] String of the arguments for command.
    def args_string args = @args
      args.flatten.compact.join(' ')
    end



  end

  class PuppetCommand < Command
    def initialize *args
      command = "puppet #{args.shift}"
      opts = args.last.is_a?(Hash) ? args.pop : Hash.new
      opts['ENV'] ||= Hash.new
      opts[:cmdexe] = true
      super( command, args, opts )
    end
  end

  class HostCommand < Command
    def cmd_line host
      eval "\"#{@command}\""
    end
  end

  class SedCommand < Command

    # sets up a SedCommand for a particular platform
    #
    # the purpose is to abstract away platform-dependent details of the sed command
    #
    # @param [String] platform The host platform string
    # @param [String] expression The sed expression
    # @param [String] filename The file to apply the sed expression to
    # @param [Hash{Symbol=>String}] opts Additional options
    # @option opts [String] :temp_file The temp file to use for in-place substitution
    #         (only applies to solaris hosts, they don't provide the -i option)
    #
    # @return a new {SedCommand} object
    def initialize platform, expression, filename, opts = {}
      command = "sed -i -e \"#{expression}\" #{filename}"
      if platform =~ /solaris|aix|osx|openbsd/
        command.slice! '-i '
        temp_file = opts[:temp_file] ? opts[:temp_file] : "#{filename}.tmp"
        command << " > #{temp_file} && mv #{temp_file} #{filename} && rm -f #{temp_file}"
      end
      args = []
      opts['ENV'] ||= Hash.new
      super( command, args, opts )
    end
  end
end
