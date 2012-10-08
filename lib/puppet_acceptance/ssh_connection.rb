module PuppetAcceptance
  class SshConnection
    def initialize(host, user=nil, options={})
      @hostname = host
      @user = user
      @options = options
    end

    def self.connect(host, user='root', options={})
      connection = new(host, user, options)
      connection.connect
      connection
    end

    def connect
      try = 1
      last_wait = 0
      wait = 1
      @ssh ||= begin
                 Net::SSH.start(@hostname, @user, @options)
               rescue
                 if try <= 10
                   puts "Try #{try} -- Host Unreachable"
                   puts "Trying again in #{wait} seconds"
                   sleep wait
                   (last_wait, wait) = wait, last_wait + wait
                   try += 1
                   retry
                 else
                   raise
                 end
               end
      self
    end

    def close
      @ssh.close if @ssh
    end

    def execute(command, options={}, stdout_callback=nil, stderr_callback=stdout_callback)
      result = Result.new(@hostname, command)
      return result if options[:dry_run]

      @ssh.open_channel do |channel|
        if options[:pty] then
          channel.request_pty do |ch, success|
            if success
              puts "Allocated a PTY on #{@hostname} for #{command.inspect}"
            else
              abort "FAILED: could not allocate a pty when requested on " +
                "#{@hostname} for #{command.inspect}"
            end
          end
        end

        channel.exec(command) do |terminal, success|
          abort "FAILED: to execute command on a new channel on #{@hostname}" unless success
          terminal.on_data do |ch, raw_data|
            stdout_callback[raw_data] if stdout_callback
              result.raw_stdout << raw_data
              result.raw_output << raw_data
              normalized_data = raw_data.gsub(/\r\n?/, "\n")
              result.stdout << normalized_data
              result.output << normalized_data
          end
          terminal.on_extended_data do |ch, type, raw_data|
            if type == 1
              stderr_callback[raw_data] if stderr_callback
              result.raw_stderr << raw_data
              result.raw_output << raw_data
              normalized_data = raw_data.gsub(/\r\n?/, "\n")
              result.stderr << normalized_data
              result.output << normalized_data
            end
          end
          terminal.on_request("exit-status") do |ch, data|
            result.exit_code = data.read_long
          end

          # queue stdin data, force it to packets, and signal eof: this
          # triggers action in many remote commands, notably including
          # 'puppet apply'.  It must be sent at some point before the rest
          # of the action.
          terminal.send_data(options[:stdin].to_s)
          terminal.process
          terminal.eof!
        end
      end

      # Process SSH activity until we stop doing that - which is when our
      # channel is finished with...
      @ssh.loop

      result
    end

    def scp_to(source, target, options={})
      return if options[:dry_run]

      recursive_scp = File.directory?(source)
      @ssh.scp.upload!(source, target, :recursive => recursive_scp)

      result = Result.new(@hostname, [source, target])

      # Setting these values allows reporting via result.log(test_name)
      result.stdout = "SCP'ed file #{source} to #{@hostname}:#{target}"

      # Net::Scp always returns 0, so just set the return code to 0.
      result.exit_code = 0

      result
    end

    def scp_from(source, target, options={})
      return if options[:dry_run]

      @ssh.scp.download!(source, target, :recursive => true)

      result = Result.new(@hostname, [source, target])

      # Setting these values allows reporting via result.log(test_name)
      result.stdout = "SCP'ed file #{@hostname}:#{source} to #{target}"

      # Net::Scp always returns 0, so just set the return code to 0.
      result.exit_code = 0

      result
    end
  end
end
