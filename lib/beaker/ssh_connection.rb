require 'socket'
require 'timeout'
require 'net/scp'

module Beaker
  class SshConnection

    attr_accessor :logger

    RETRYABLE_EXCEPTIONS = [
      SocketError,
      Timeout::Error,
      Errno::ETIMEDOUT,
      Errno::EHOSTDOWN,
      Errno::EHOSTUNREACH,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::ENETUNREACH,
      Net::SSH::Disconnect,
      Net::SSH::AuthenticationFailed,
      IOError,
    ]

    def initialize hostname, user = nil, ssh_opts = {}, options = {}
      @hostname = hostname
      @user = user
      @ssh_opts = ssh_opts
      @logger = options[:logger]
      @options = options
    end

    def self.connect hostname, user = 'root', ssh_opts = {}, options = {}
      connection = new hostname, user, ssh_opts, options
      connection.connect
      connection
    end

    # connect to the host
    def connect
      try = 1
      last_wait = 0
      wait = 1
      @ssh ||= begin
                 @logger.debug "Attempting ssh connection to #{@hostname}, user: #{@user}, opts: #{@ssh_opts}"
                 Net::SSH.start(@hostname, @user, @ssh_opts)
               rescue *RETRYABLE_EXCEPTIONS => e
                 if try <= 11
                   @logger.warn "Try #{try} -- Host #{@hostname} unreachable: #{e.class.name} - #{e.message}"
                   @logger.warn "Trying again in #{wait} seconds"
                   sleep wait
                  (last_wait, wait) = wait, last_wait + wait
                   try += 1
                   retry
                 else
                   @logger.error "Failed to connect to #{@hostname}"
                   raise
                 end
               end
    end

    # closes this SshConnection
    def close
      begin
        if @ssh and not @ssh.closed?
          @ssh.close
        else
          @logger.warn("ssh.close: connection is already closed, no action needed")
        end
      rescue *RETRYABLE_EXCEPTIONS => e
        @logger.warn "Attemped ssh.close, (caught #{e.class.name} - #{e.message})."
      rescue => e
        @logger.warn "ssh.close threw unexpected Error: #{e.class.name} - #{e.message}.  Shutting down, and re-raising error below"
        @ssh.shutdown!
        raise e
      ensure
        @ssh = nil
        @logger.warn("ssh connection to #{@hostname} has been terminated")
      end
    end

    #We expect the connection to close so wait for that to happen
    def wait_for_connection_failure
      try = 1
      last_wait = 0
      wait = 1
      while try < 11
        begin
          @logger.debug "Waiting for connection failure on #{@hostname} (attempt #{try}, try again in #{wait} second(s))"
          @ssh.open_channel do |channel|
            channel.exec('') #Just send something down the pipe
          end
          loop_tries = 0
          #loop is actually loop_forver, so let it try 3 times and then quit instead of endless blocking
          @ssh.loop { loop_tries += 1 ; loop_tries < 4 }
        rescue *RETRYABLE_EXCEPTIONS => e
          @logger.debug "Connection on #{@hostname} failed as expected (#{e.class.name} - #{e.message})"
          close #this connection is bad, shut it down
          return true
        end
        sleep wait
        (last_wait, wait) = wait, last_wait + wait
        try += 1
      end
      false
    end

    def try_to_execute command, options = {}, stdout_callback = nil,
                stderr_callback = stdout_callback

      result = Result.new(@hostname, command)
      # why are we getting to this point on a dry run anyways?
      # also... the host creates connections through the class method,
      # which automatically connects, so you can't do a dry run unless you also
      # can connect to your hosts?
      return result if options[:dry_run]

      @ssh.open_channel do |channel|
        request_terminal_for( channel, command ) if options[:pty]

        channel.exec(command) do |terminal, success|
          abort "FAILED: to execute command on a new channel on #{@hostname}" unless success
          register_stdout_for terminal, result, stdout_callback
          register_stderr_for terminal, result, stderr_callback
          register_exit_code_for terminal, result

          process_stdin_for( terminal, options[:stdin] ) if options[:stdin]
        end
      end

      # Process SSH activity until we stop doing that - which is when our
      # channel is finished with...
      begin
        @ssh.loop
      rescue *RETRYABLE_EXCEPTIONS => e
        # this would indicate that the connection failed post execution, since the channel exec was successful
        @logger.warn "ssh channel on #{@hostname} received exception post command execution #{e.class.name} - #{e.message}"
        close
      end

      result.finalize!
      @logger.last_result = result
      result
    end

    def execute command, options = {}, stdout_callback = nil,
                stderr_callback = stdout_callback
      try = 1
      wait = 1
      last_wait = 0
      begin
        # ensure that we have a current connection object
        connect
        result = try_to_execute(command, options, stdout_callback, stderr_callback)
      rescue *RETRYABLE_EXCEPTIONS => e
        if try < 11
           sleep wait
          (last_wait, wait) = wait, last_wait + wait
           try += 1
          @logger.error "Command execution '#{@hostname}$ #{command}' failed (#{e.class.name} - #{e.message})"
          close
          @logger.debug "Preparing to retry: closed ssh object"
          retry
        else
          raise
        end
      end

      result
    end

    def request_terminal_for channel, command
      channel.request_pty do |ch, success|
        if success
          @logger.info "Allocated a PTY on #{@hostname} for #{command.inspect}"
        else
          abort "FAILED: could not allocate a pty when requested on " +
            "#{@hostname} for #{command.inspect}"
        end
      end
    end

    def register_stdout_for channel, output, callback = nil
      channel.on_data do |ch, data|
        callback[data] if callback
        output.stdout << data
        output.output << data
      end
    end

    def register_stderr_for channel, output, callback = nil
      channel.on_extended_data do |ch, type, data|
        if type == 1
          callback[data] if callback
          output.stderr << data
          output.output << data
        end
      end
    end

    def register_exit_code_for channel, output
      channel.on_request("exit-status") do |ch, data|
        output.exit_code = data.read_long
      end
    end

    def process_stdin_for channel, stdin
      # queue stdin data, force it to packets, and signal eof: this
      # triggers action in many remote commands, notably including
      # 'puppet apply'.  It must be sent at some point before the rest
      # of the action.
      channel.send_data stdin.to_s
      channel.process
      channel.eof!
    end

    def scp_to source, target, options = {}, dry_run = false
      return if dry_run

      local_opts = options.dup
      if local_opts[:recursive].nil?
        local_opts[:recursive] = File.directory?(source)
      end
      local_opts[:chunk_size] ||= 16384

      result = Result.new(@hostname, [source, target])
      result.stdout = "\n"
      @ssh.scp.upload! source, target, local_opts do |ch, name, sent, total|
        result.stdout << "\tcopying %s: %10d/%d\n" % [name, sent, total]
      end

      # Setting these values allows reporting via result.log(test_name)
      result.stdout << "  SCP'ed file #{source} to #{@hostname}:#{target}"

      # Net::Scp always returns 0, so just set the return code to 0.
      result.exit_code = 0

      result.finalize!
      return result
    end

    def scp_from source, target, options = {}, dry_run = false
      return if dry_run

      local_opts = options.dup
      if local_opts[:recursive].nil?
        local_opts[:recursive] = true
      end
      local_opts[:chunk_size] ||= 16384

      result = Result.new(@hostname, [source, target])
      result.stdout = "\n"
      @ssh.scp.download! source, target, local_opts do |ch, name, sent, total|
        result.stdout << "\tcopying %s: %10d/%d\n" % [name, sent, total]
      end

      # Setting these values allows reporting via result.log(test_name)
      result.stdout << "  SCP'ed file #{@hostname}:#{source} to #{target}"

      # Net::Scp always returns 0, so just set the return code to 0.
      result.exit_code = 0

      result.finalize!
      result
    end
  end
end
