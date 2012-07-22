require File.expand_path(File.join(File.dirname(__FILE__), 'puppet_commands'))

module PuppetAcceptance
  class Host    # < Struct.new :name, :options, :config
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

    def ssh_connection
      host = self['ip'] || @name
      @ssh_connection ||= SshConnection.connect(host, self['user'], self['ssh'])
    end

    def close
      @ssh_connection.close if @ssh_connection
    end

    def exec command, options={}
      # I've always found this confusing
      cmdline = command.cmd_line(self)

      @logger.debug "\n#{self} $ #{cmdline}"

      # these really should be the options that are passed to exec, or they should
      # be, really, passed to the connection constructor.
      ssh_options = {
        :stdin => options[:stdin],
        :pty => options[:pty],
        :dry_run => $dry_run,
      }

      output_callback = logger.method(:host_output)

      # is this returning a result object?
      # the options should come at the end of the method signature (rubyism)
      # and they shouldn't be ssh specific
      result = ssh_connection.execute(cmdline, ssh_options, output_callback)

      # This should be in the logger, it's passed the configuration object and
      # it should decide what it prints to where based on how it's been configured.
      # Ultimately it doesn't have to be the logger, but we need to not put this
      # info everywhere...
      # actually I don't think this value could be in this options hash, every other
      # use is from the options passed to `on` but this is from the harness' options
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

    def do_scp_to(source, target)
      @logger.debug "localhost $ scp #{source} #{self}:#{target}"

      ssh_options = {
        :dry_run => $dry_run,
      }

      ssh_connection.scp_to(source, target, ssh_options)
    end

    def do_scp_from(source, target)
      @logger.debug "localhost $ scp #{self}:#{source} #{target}"

      ssh_options = {
          :dry_run => $dry_run,
      }

      ssh_connection.scp_from(source, target, ssh_options)
    end
  end

  require File.expand_path(File.join(File.dirname(__FILE__), 'host/windows'))
  require File.expand_path(File.join(File.dirname(__FILE__), 'host/unix'))
end
