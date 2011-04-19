class TestCase
  class Host
    # A cache for active SSH connections to our execution nodes.
    def initialize(name, overrides, defaults)
      @name,@overrides,@defaults = name,overrides,defaults
    end
    def []=(k,v)
      @overrides[k] = v
    end
    def [](k)
      @overrides.has_key?(k) ? @overrides[k] : @defaults[k]
    end
    def to_str
      @name
    end
    def to_s
      @name
    end
    def +(other)
      @name+other
    end

    # Wrap up the SSH connection process; this will cache the connection and
    # allow us to reuse it for each operation without needing to reauth every
    # single time.
    def ssh
      @ssh ||= Net::SSH.start(self, self['user'] || "root" , self['ssh'])
    end

    def do_action(verb,*args)
      result = Result.new(self,args,'','',0)
      Log.debug "#{self}: #{verb}(#{args.inspect})"
      yield result unless $dry_run
      result
    end

    def exec(command, stdin)
      do_action('RemoteExec',command) do |result|
        ssh.open_channel do |channel|
          channel.exec(command) do |terminal, success|
            abort "FAILED: to execute command on a new channel on #{@name}" unless success
            terminal.on_data                   { |ch, data|       result.stdout << data }
            terminal.on_extended_data          { |ch, type, data| result.stderr << data if type == 1 }
            terminal.on_request("exit-status") { |ch, data|       result.exit_code = data.read_long  }

            # queue stdin data, force it to packets, and signal eof: this
            # triggers action in many remote commands, notably including
            # 'puppet apply'.  It must be sent at some point before the rest
            # of the action.
            terminal.send_data(stdin.to_s)
            terminal.process
            terminal.eof!
          end
        end
        # Process SSH activity until we stop doing that - which is when our
        # channel is finished with...
        ssh.loop
      end
    end

    def do_scp(source, target)
      do_action("ScpFile",source,target) { |result|
        # Net::Scp always returns 0, so just set the return code to 0 Setting
        # these values allows reporting via result.log(test_name)
        result.stdout = "SCP'ed file #{source} to #{@host}:#{target}"
        result.stderr=nil
        result.exit_code=0
        ssh.scp.upload!(source, target)
      }
    end
  end
end
