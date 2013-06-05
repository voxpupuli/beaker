module PuppetAcceptance
  # An object that represents a "command" on a remote host. Is responsible
  # for munging the environment correctly. Probably poorly named.
  #
  # @api public
  class Command

    DEFAULT_GIT_RUBYLIB = {
      :default => [],
      :host => %w(hieralibdir hierapuppetlibdir
                  pluginlibpath puppetlibdir
                  facterlibdir),
      :opts => { :additive => true,
                 :separator => {:host => 'pathseparator' }
      }
    }

    DEFAULT_GIT_PATH = {
      :default => [],
      :host => %w(puppetbindir facterbindir hierabindir),
      :opts => { :additive => true, :separator => ':' }
    }

    DEFAULT_GIT_ENV = { :PATH => DEFAULT_GIT_PATH, :RUBYLIB => DEFAULT_GIT_RUBYLIB }

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

      # this is deprecated and will not allow you to use a command line
      # option of `--environment`, please use ENV instead.
      if @options[:environment].is_a?(Hash)
        @environment = @options.delete(:environment)
      elsif @options['ENV'].is_a?(Hash) or @options[:ENV].is_a?(Hash)
        @environment = @options.delete('ENV')
      else
        @environment = nil
      end
    end

    # @param [Host]   host An object that implements {PuppetAcceptance::Host}'s
    #                      interface.
    # @param [String] cmd  An command to call.
    # @param [Hash]   env  An optional hash of environment variables to be used
    #
    # @return [String] This returns the fully formed command line invocation.
    def cmd_line host, cmd = @command, env = @environment
      env_string = env.nil? ? '' : environment_string_for( host, env )

      # This will cause things like `puppet -t -v agent` which is maybe bad.
      "#{env_string} #{cmd} #{options_string} #{args_string}"
    end

    # @param [Hash] options These are the options that the command takes
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

    # Determine the appropriate env commands for the given host.
    #
    # @param [Host]                 host  A Host object
    # @param [Hash{String=>String}] env   An optional Hash containing
    #                                     key-value pairs to be treated
    #                                     as environment variables that
    #                                     should be set for the duration
    #                                     of the puppet command.
    #
    # @return [String] Returns a string containing command line arguments that
    #                  will ensure the environment is correctly set for the
    #                  given host.
    #
    # @note I dislike the principle of this method. There is host specific
    #       knowledge contained here. Really the relationship should be
    #       reversed where a host is asked for an appropriate Command when
    #       given a generic Command.
    def environment_string_for host, env = {}
      return '' if env.empty?

      env_array = parse_env_hash_for( host, env ).compact

      # cygwin-ism
      cmd = host['platform'] =~ /windows/ ? 'cmd.exe /c' : nil
      env_array << cmd if cmd

      environment_string = env_array.join(' ')

      "env #{environment_string}"
    end

    # @!visibility private
    def parse_env_hash_for( host, env = @environment )
      # I needlessly love inject
      env.inject([]) do |array_of_parsed_vars, key_and_value|
        variable, val_in_unknown_format = *key_and_value
        if val_in_unknown_format.is_a?(Hash)
          value = val_in_unknown_format
        elsif val_in_unknown_format.is_a?(Array)
          value = { :default => val_in_unknown_format }
        else
          value = { :default => [ val_in_unknown_format.to_s ] }
        end

        var_settings = ensure_correct_structure_for( value )
        # any default array of variable values ( like [ '/bin', '/usr/bin' ] for PATH )
        default_values = var_settings[:default]

        # host specific values, ie :host => [ 'puppetlibdir' ] is evaluated to
        # an array with whatever host['puppetlibdir'] is
        host_values = var_settings[:host].map { |attr| host[attr] }

        # the two arrays are combined with host specific values first
        var_array = ( host_values + default_values ).compact

        # This will add the name of the variable, so :PATH => { ... }
        # gets '${PATH}' appended to it if the :additive opt is passed
        var_array << "${#{variable}}" if var_settings[:opts][:additive]

        # This is stupid, but because we're using cygwin we sometimes need to use
        # ':' and sometimes ';' on windows as a separator
        attr_string = join_env_vars_for( var_array, host, var_settings[:opts][:separator] )
        var_string = attr_string.empty? ? nil : %Q[#{variable}="#{attr_string}"]

        # Now we append this to our accumulator array ie [ 'RUBYLIB=....', 'PATH=....' ]
        array_of_parsed_vars << var_string

        array_of_parsed_vars
      end
    end

    # @!visibility private
    def ensure_correct_structure_for( settings )
      structure = { :default => [],
        :host => [],
        :opts => {}
      }.merge( settings )
      structure[:opts][:separator] ||= ':'
      structure
    end

    # @!visibility private
    def join_env_vars_for( array_of_variables, host, separator = ':' )
      if separator.is_a?( Hash )
        separator = host[separator[:host]]
      end
      array_of_variables.join( separator )
    end
  end

  class PuppetCommand < Command
    def initialize *args
      command = "puppet #{args.shift}"
      opts = args.last.is_a?(Hash) ? args.pop : Hash.new
      opts['ENV'] ||= Hash.new
      opts['ENV'] = opts['ENV'].merge( DEFAULT_GIT_ENV )
      super( command, args, opts )
    end
  end

  class HostCommand < Command
    def cmd_line host
      eval "\"#{@command}\""
    end
  end
end
