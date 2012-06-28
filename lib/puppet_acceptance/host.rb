require File.expand_path(File.join(File.dirname(__FILE__), 'puppet_commands'))

module PuppetAcceptance
  class Host
    include PuppetCommands

    def self.create(name, options, config)
      case config['HOSTS'][name]['platform']
      when /windows/
        Windows::Host.new(name, options, config)
      else
        Unix::Host.new(name, options, config)
      end
    end

    attr_accessor :logger
    attr_reader :name, :defaults
    def initialize(name, options, config)
      @logger = options[:logger]
      @name, @options, @config = name, options.dup, config
      @defaults = merge_defaults_for_type(@config, options[:type])
    end

    def merge_defaults_for_type(config, type)
      defaults = type =~ /pe/ ? self.class.pe_defaults : self.class.foss_defaults
      config['CONFIG'].merge(defaults).merge(config['HOSTS'][name])
    end

    def node_name()
      # TODO: might want to consider caching here; not doing it for now because
      #  I haven't thought through all of the possible scenarios that could
      #  cause the value to change after it had been cached.
      result = exec(puppet_agent("--configprint node_name_value"))
      result.stdout.chomp
    end



    def []=(k,v)
      @defaults[k] = v
    end

    def [](k)
      @defaults[k]
    end

    def to_str
      @name
    end

    def to_s
      @name
    end

    def +(other)
      @name + other
    end

    def is_pe?
      @config.is_pe?
    end

    def ssh_connection
      @ssh_connection ||= SshConnection.connect(self, self['user'], self['ssh'])
    end

    def close
      @ssh_connection.close if @ssh_connection
    end

    def exec(command, options={})
      cmdline = command.cmd_line(self)

      @logger.debug "\n#{self} $ #{cmdline}"

      ssh_options = {
        :stdin => options[:stdin],
        :pty => options[:pty],
        :dry_run => $dry_run,
      }

      output_callback = logger.method(:host_output)

      result = ssh_connection.execute(cmdline, ssh_options, output_callback)

      unless options[:silent]
        result.log(@logger)
        unless result.exit_code_in?(options[:acceptable_exit_codes] || [0])
          limit = 10
          raise "Host '#{self}' exited with #{result.exit_code} running:\n #{cmdline}\nLast #{limit} lines of output were:\n#{result.formatted_output(limit)}"
        end
      end
      result
    end

    def do_scp(source, target)
      @logger.debug "localhost $ scp #{source} #{self}:#{target}"

      ssh_options = {
        :dry_run => $dry_run,
      }

      ssh_connection.scp(source, target, ssh_options)
    end
  end

  require File.expand_path(File.join(File.dirname(__FILE__), 'host/windows'))
  require File.expand_path(File.join(File.dirname(__FILE__), 'host/unix'))
end
