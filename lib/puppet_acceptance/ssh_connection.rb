module PuppetAcceptance
  class SshConnection
    def initialize(host, user=nil, options={})
      @host = host
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
      @ssh ||= begin
                 Net::SSH.start(@host, @user, @options)
               rescue
                 try += 1
                 if try < 4
                   puts "Try #{try} -- Host Unreachable"
                   puts 'Trying again in 20 seconds'
                   sleep 20
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
      result = Result.new(@host, command)
      return result if options[:dry_run]

      @ssh.open_channel do |channel|
        if options[:pty] then
          channel.request_pty do |ch, success|
            if success
              puts "Allocated a PTY on #{@host.name} for #{command.inspect}"
            else
              abort "FAILED: could not allocate a pty when requested on " +
                "#{@host.name} for #{command.inspect}"
            end
          end
        end

        channel.exec(command) do |terminal, success|
          abort "FAILED: to execute command on a new channel on #{@host.name}" unless success
          terminal.on_data do |ch, data|
            stdout_callback[data] if stdout_callback
            result.stdout << data
            result.output << data
          end
          terminal.on_extended_data do |ch, type, data|
            if type == 1
              stderr_callback[data] if stderr_callback
              result.stderr << data
              result.output << data
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

    def scp(source, target, options={})
      return if options[:dry_run]

      recursive_scp = File.directory?(source)
      @ssh.scp.upload!(source, target, :recursive => recursive_scp)

      result = Result.new(@host, [source, target])

      # Setting these values allows reporting via result.log(test_name)
      result.stdout = "SCP'ed file #{source} to #{@host}:#{target}"

      # Net::Scp always returns 0, so just set the return code to 0.
      result.exit_code = 0

      result
    end
  end
end
