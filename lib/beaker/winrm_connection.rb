require 'socket'
require 'timeout'
require 'winrm'
require 'winrm-fs'

module Beaker
  class WinrmConnection

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
      IOError,
    ]

    def initialize hostname, winrm_opts = {}, options ={}
      @hostname = hostname
      @winrm_opts = winrm_opts
      @logger = options[:logger]
      @options = options
    end

    def self.connect hostname, winrm_opts = {}, options ={}
      connection = new hostname, winrm_opts, options
      connection.connect
      connection
    end

    # connect to the host
    def connect
      try = 1
      last_wait = 0
      wait = 1
      @winrm ||= begin
                @logger.debug "Attempting winrm connection to #{@hostname}, opts: #{@winrm_opts}"
                endpoint = "http://#{@hostname}:5985/wsman"
                auth = @winrm_opts['auth']
                
                case auth
                when 'kerberos'
                  krb5_realm = @winrm_opts['realm']
                  WinRM::WinRMWebService.new(endpoint, :kerberos, :realm => krb5_realm)
                when 'plaintext'
                  user = @winrm_opts['user']
                  pass = @winrm_opts['pass']
                  WinRM::WinRMWebService.new(endpoint, :plaintext, :user => user, :pass => pass, :basic_auth_only => true)
                when 'ssl'
                  user = @winrm_opts['user']
                  pass = @winrm_opts['pass']
                  ca_trust_path = @winrm_opts['ca_trust_path']
                  WinRM::WinRMWebService.new(endpoint, :ssl, :user => user, :pass => pass, :ca_trust_path => ca_trust_path, :basic_auth_only => true)
                else
                  @logger.error "Invalid authentication method #{auth}, supported: kerberos, plaintext, ssl."
                  raise
                end
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

    # closes this winrmConnection
    def close
      begin
        if @winrm and @sid
          @winrm.close_shell(@sid)
        else
          @logger.warn("winrm.close: connection is already closed, no action needed")
        end
      rescue *RETRYABLE_EXCEPTIONS => e
        @logger.warn "Attemped winrm.close, (caught #{e.class.name} - #{e.message})."
      rescue => e
        @logger.warn "winrm.close threw unexpected Error: #{e.class.name} - #{e.message}.  Shutting down, and re-raising error below"
        raise e
      ensure
        @winrm = nil
        @logger.warn("winrm connection to #{@hostname} has been terminated")
      end
    end

    def execute command, options= {}, stdout
      try = 1
      wait = 1
      last_wait = 0
      output = WinRM::Output.new
      result = Result.new(@hostname, command)

      begin
        # ensure that we have a current connection object
        connect
        @sid = @winrm.open_shell
        if @sid
          @logger.info "Open a shell on #{@hostname} for #{command.inspect}"
          cmd_id = @winrm.run_command(@sid, command)
          output = @winrm.get_command_output(@sid, cmd_id)
          result.stdout = output.stdout
          result.stderr = output.stderr
          result.exit_code = output[:exitcode]

          @logger.debug "STDOUT: #{result.stdout}" unless result.stdout.nil? || result.stdout == ''
          @logger.debug "STDERR: #{result.stderr}" unless result.stderr.nil? || result.stderr == ''
          @logger.debug "Exit Code: #{result.exit_code}" unless result.exit_code.nil? || result.exit_code == ''

        else
          abort "FAILED: could not open a shell on #{@hostname} for #{command.inspect}"
        end
      rescue *RETRYABLE_EXCEPTIONS => e
        if try < 11
           sleep wait
          (last_wait, wait) = wait, last_wait + wait
           try += 1
          @logger.error "Command execution '#{@hostname}$ #{command}' failed (#{e.class.name} - #{e.message})"
          close
          @logger.debug "Preparing to retry: closed winrm object"
          retry
        else
          raise
        end
      end
      result.finalize!
      @logger.last_result = result
      result
      # Close the shell to avoid the quota of 5 concurrent shells for a user by default.
      close
      @sid = nil
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
      file_manager = WinRM::FS::FileManager.new(@winrm)
      file_manager.upload(source, target) do |bytes_copied, total_bytes, local_path, remote_path|
        result.stdout <<  "\t#{bytes_copied}bytes of #{total_bytes}bytes copied\n"
      end

      # Setting these values allows reporting via result.log(test_name)
      result.stdout << "  Copied file #{source} to #{@hostname}:#{target}"

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
      file_manager = WinRM::FS::FileManager.new(@winrm)
      file_manager.download(source, target) do |bytes_copied, total_bytes, local_path, remote_path|
        result.stdout <<  "\t#{bytes_copied}bytes of #{total_bytes}bytes copied\n"
      end

      # Setting these values allows reporting via result.log(test_name)
      result.stdout << "  Copied file #{@hostname}:#{source} to #{target}"

      # Net::Scp always returns 0, so just set the return code to 0.
      result.exit_code = 0

      result.finalize!
      result
    end
  end
end