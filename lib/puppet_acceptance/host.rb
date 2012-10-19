require File.expand_path(File.join(File.dirname(__FILE__), 'puppet_commands'))

module PuppetAcceptance
  class Host
    include PuppetCommands

    def self.create name, options, config
      case config['HOSTS'][name]['platform']
      when /windows/
        Windows::Host.new name, options, config
      else
        Unix::Host.new name, options, config
      end
    end

    attr_accessor :logger
    attr_reader :name, :defaults
    def initialize name, options, config
      @logger = options[:logger]
      @name, @options, @config = name, options.dup, config

      # This is annoying and its because of drift/lack of enforcement/lack of having
      # a explict relationship between our defaults, our setup steps and how they're
      # related through 'type' and the differences between the assumption of our two
      # configurations we have for many of our products
      type = is_pe? ? :pe : :foss
      @defaults = merge_defaults_for_type @config, type
    end

    def merge_defaults_for_type config, type
      defaults = self.class.send "#{type}_defaults".to_sym
      defaults.merge(config['CONFIG']).merge(config['HOSTS'][name])
    end

    def node_name
      # TODO: might want to consider caching here; not doing it for now because
      #  I haven't thought through all of the possible scenarios that could
      #  cause the value to change after it had been cached.
      result = exec puppet_agent("--configprint node_name_value")
      result.stdout.chomp
    end

    def []= k, v
      @defaults[k] = v
    end

    def [] k
      @defaults[k]
    end

    def to_str
      @name
    end

    def to_s
      @name
    end

    def + other
      @name + other
    end

    def is_pe?
      @config.is_pe?
    end

    def connection
      @connection ||= SshConnection.connect( self['ip'] || @name,
                                             self['user'],
                                             self['ssh'] )
    end

    def close
      @connection.close if @connection
    end

    def exec command, options={}
      # I've always found this confusing
      cmdline = command.cmd_line(self)

      @logger.debug "\n#{self} $ #{cmdline}" unless options[:silent]

      output_callback = logger.method(:host_output)

      unless $dry_run
        # is this returning a result object?
        # the options should come at the end of the method signature (rubyism)
        # and they shouldn't be ssh specific
        result = connection.execute(cmdline, options, output_callback)

        unless options[:silent]
          # What?
          result.log(@logger)
          # No, TestCase has the knowledge about whether its failed, checking acceptable
          # exit codes at the host level and then raising...
          # is it necessary to break execution??
          unless result.exit_code_in?(options[:acceptable_exit_codes] || [0])
            limit = 10
            raise "Host '#{self}' exited with #{result.exit_code} running:\n #{cmdline}\nLast #{limit} lines of output were:\n#{result.formatted_output(limit)}"
          end
        end
        # Danger, so we have to return this result?
        result
      end
    end

    def do_scp_to source, target, options
      @logger.debug "localhost $ scp #{source} #{@name}:#{target}"

      options[:dry_run] = $dry_run,

      result = connection.scp_to(source, target, options)
      return result
    end

    def do_scp_from source, target, options
      @logger.debug "localhost $ scp #{@name}:#{source} #{target}"

      options[:dry_run] = $dry_run

      result = connection.scp_from(source, target, options)
      return result
    end
  end

  require File.expand_path(File.join(File.dirname(__FILE__), 'host/windows'))
  require File.expand_path(File.join(File.dirname(__FILE__), 'host/unix'))
end
