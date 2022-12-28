require 'open3'

module Beaker
  class LocalConnection

    attr_accessor :logger, :hostname, :ip

    def initialize options = {}
      @logger = options[:logger]
      @ssh_env_file = File.expand_path(options[:ssh_env_file])
      @hostname = 'localhost'
      @ip = '127.0.0.1'
      @options = options
    end

    def self.connect options = {}
      connection = new options
      connection.connect
      connection
    end

    def connect _options = {}
      @logger.debug "Local connection, no connection to start"
    end

    def close
      @logger.debug "Local connection, no connection to close"
    end

    def with_env(env)
      backup = ENV.to_hash
      ENV.replace(env)
      yield
    ensure
      ENV.replace(backup)
    end

    def execute command, _options = {}, stdout_callback = nil, _stderr_callback = stdout_callback
      result = Result.new(@hostname, command)
      envs = {}
      if File.readable?(@ssh_env_file)
        File.foreach(@ssh_env_file) do |line|
          key, value = line.split('=')
          envs[key] = value
        end
      end

      begin
        clean_env = ENV.reject{ |k| /^BUNDLE|^RUBY|^GEM/.match?(k) }

        with_env(clean_env) do
          std_out, std_err, status = Open3.capture3(envs, command)
          result.stdout << std_out
          result.stderr << std_err
          result.exit_code = status.exitstatus
          @logger.info(result.stdout) unless result.stdout.empty?
          @logger.info(result.stderr) unless result.stderr.empty?
        end
      rescue => e
        result.stderr << e.inspect
        @logger.info(result.stderr)
        result.exit_code = 1
      end

      result.finalize!
      @logger.last_result = result
      result
    end

    def scp_to(source, target, _options = {})

      result = Result.new(@hostname, [source, target])
      begin
        FileUtils.cp_r source, target
      rescue Errno::ENOENT => e
        @logger.warn "#{e.class} error in cp'ing. Forcing the connection to close, which should " \
                        "raise an error."
      end

      result.stdout << "  CP'ed file #{source} to #{target}"
      result.exit_code = 0
      result
    end

    def scp_from(source, target, options = {})
      scp_to(target, source, options)
    end
  end
end
