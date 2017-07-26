require 'socket'
require 'timeout'
require 'net/scp'

module Beaker
  class SshConnection

    attr_accessor :logger
    attr_accessor :ip, :vmhostname, :hostname

    RETRYABLE_EXCEPTIONS = [
      SocketError,
      Timeout::Error,
      Errno::ETIMEDOUT,
      Errno::EHOSTDOWN,
      Errno::EHOSTUNREACH,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::ENETUNREACH,
      Net::SSH::Exception,
      Net::SSH::Disconnect,
      Net::SSH::AuthenticationFailed,
      Net::SSH::ChannelRequestFailed,
      Net::SSH::ChannelOpenFailed,
      IOError,
    ]

    def initialize name_hash, user = nil, ssh_opts = {}, options = {}
      @vmhostname = name_hash[:vmhostname]
      @ip = name_hash[:ip]
      @hostname = name_hash[:hostname]
      @user = user
      @ssh_opts = ssh_opts
      @logger = options[:logger]
      @options = options
    end

    def self.connect name_hash, user = 'root', ssh_opts = {}, options = {}
      connection = new name_hash, user, ssh_opts, options
      connection.connect
      connection
    end

    def connect_block host, user, ssh_opts
      try = 1
      last_wait = 2
      wait = 3
      begin
         @logger.debug "Attempting ssh connection to #{host}, user: #{user}, opts: #{ssh_opts}"
         Net::SSH.start(host, user, ssh_opts)
       rescue *RETRYABLE_EXCEPTIONS => e
         if try <= 11
           @logger.warn "Try #{try} -- Host #{host} unreachable: #{e.class.name} - #{e.message}"
           @logger.warn "Trying again in #{wait} seconds"
           sleep wait
          (last_wait, wait) = wait, last_wait + wait
           try += 1
           retry
         else
           @logger.warn "Failed to connect to #{host}, after #{try} attempts"
           nil
         end
       end
    end

    # connect to the host
    def connect
      #try three ways to connect to host (vmhostname, ip, hostname)
      methods = []
      if @vmhostname
        @ssh ||= connect_block(@vmhostname, @user, @ssh_opts)
        methods << "vmhostname (#{@vmhostname})"
      end
      if @ip && !@ssh
        @ssh ||= connect_block(@ip, @user, @ssh_opts)
        methods << "ip (#{@ip})"
      end
      if @hostname && !@ssh
        @ssh ||= connect_block(@hostname, @user, @ssh_opts)
        methods << "hostname (#{@hostname})"
      end
      if not @ssh
        @logger.error "Failed to connect to #{@hostname}, attempted #{methods.join(', ')}"
        raise RuntimeError, "Cannot connect to #{@hostname}"
      end
      @ssh
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
        @logger.debug("ssh connection to #{@hostname} has been terminated")
      end
    end

    # Wait for the ssh connection to fail, returns true on connection failure and false otherwise
    # @param [Hash{Symbol=>String}] options Options hash to control method conditionals
    # @option options [Boolean] :pty Should we request a terminal when attempting
    #                                to send a command over this connection?
    # @option options [String] :stdin Any input to be sent along with the command
    # @param [IO] stdout_callback An IO stream to send connection stdout to, defaults to nil
    # @param [IO] stderr_callback An IO stream to send connection stderr to, defaults to nil
    # @return [Boolean] true if connection failed, false otherwise
    def wait_for_connection_failure options = {}, stdout_callback = nil, stderr_callback = stdout_callback
      try = 1
      last_wait = 2
      wait = 3
      command = 'echo echo' #can be run on all platforms (I'm looking at you, windows)
      while try < 11
        result = Result.new(@hostname, command)
        begin
          @logger.notify "Waiting for connection failure on #{@hostname} (attempt #{try}, try again in #{wait} second(s))"
          @logger.debug("\n#{@hostname} #{Time.new.strftime('%H:%M:%S')}$ #{command}")
          @ssh.open_channel do |channel|
            request_terminal_for( channel, command ) if options[:pty]

            channel.exec(command) do |terminal, success|
              raise Net::SSH::Exception.new("FAILED: to execute command on a new channel on #{@hostname}") unless success
              register_stdout_for terminal, result, stdout_callback
              register_stderr_for terminal, result, stderr_callback
              register_exit_code_for terminal, result

              process_stdin_for( terminal, options[:stdin] ) if options[:stdin]
             end
           end
           loop_tries = 0
           #loop is actually loop_forever, so let it try 3 times and then quit instead of endless blocking
           @ssh.loop { loop_tries += 1 ; loop_tries < 4 }
        rescue *RETRYABLE_EXCEPTIONS => e
          @logger.debug "Connection on #{@hostname} failed as expected (#{e.class.name} - #{e.message})"
          close #this connection is bad, shut it down
          return true
        end
        slept = 0
        stdout_callback.call("sleep #{wait} second(s): ")
        while slept < wait
          sleep slept
          stdout_callback.call('.')
          slept += 1
        end
        stdout_callback.call("\n")
        (last_wait, wait) = wait, last_wait + wait
        try += 1
      end
      false
    end

    def try_to_execute command, options = {}, stdout_callback = nil,
                stderr_callback = stdout_callback

      result = Result.new(@hostname, command)

      @ssh.open_channel do |channel|
        request_terminal_for( channel, command ) if options[:pty]

        channel.exec(command) do |terminal, success|
          raise Net::SSH::Exception.new("FAILED: to execute command on a new channel on #{@hostname}") unless success
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
          @logger.debug "Allocated a PTY on #{@hostname} for #{command.inspect}"
        else
          raise Net::SSH::Exception.new("FAILED: could not allocate a pty when requested on " +
            "#{@hostname} for #{command.inspect}")
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

    def scp_to source, target, options = {}

      local_opts = options.dup
      if local_opts[:recursive].nil?
        local_opts[:recursive] = File.directory?(source)
      end
      local_opts[:chunk_size] ||= 16384

      result = Result.new(@hostname, [source, target])
      result.stdout = "\n"

      begin
        @ssh.scp.upload! source, target, local_opts do |ch, name, sent, total|
          result.stdout << "\tcopying %s: %10d/%d\n" % [name, sent, total]
        end
      rescue => e
        logger.warn "#{e.class} error in scp'ing. Forcing the connection to close, which should " <<
          "raise an error."
        close
      end


      # Setting these values allows reporting via result.log(test_name)
      result.stdout << "  SCP'ed file #{source} to #{@hostname}:#{target}"

      # Net::Scp always returns 0, so just set the return code to 0.
      result.exit_code = 0

      result.finalize!
      return result
    end

    def scp_from source, target, options = {}

      local_opts = options.dup
      if local_opts[:recursive].nil?
        local_opts[:recursive] = true
      end
      local_opts[:chunk_size] ||= 16384

      result = Result.new(@hostname, [source, target])
      result.stdout = "\n"

      begin
        @ssh.scp.download! source, target, local_opts do |ch, name, sent, total|
          result.stdout << "\tcopying %s: %10d/%d\n" % [name, sent, total]
        end
      rescue => e
        logger.warn "#{e.class} error in scp'ing. Forcing the connection to close, which should " <<
          "raise an error."
        close
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
