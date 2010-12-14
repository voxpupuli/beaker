# Remote command execution
# Accpets host name a remote command to execute
# Returns object "result"
require 'lib/action'

class RemoteExec < Action
  def do_remote(cmd, stdin = '')
    do_action(cmd) { |result,options|
      Net::SSH.start(host, "root", options) do |ssh|
        ssh.open_channel do |channel|
          channel.exec(cmd) do |ch, success|
            abort "FAILED: couldn't execute command (ssh.channel.exec failure)" unless success

            ch.on_data { |ch, data| result.stdout << data }
            ch.on_extended_data { |ch, type, data| result.stderr << data if type == 1 }
            ch.on_request("exit-status") { |ch, data|
              result.exit_code = data.read_long
            }

            # queue stdin data, force it to packets, and signal eof: this
            # triggers action in many remote commands, notably including
            # 'puppet apply'.  It must be sent at some point before the rest
            # of the action.
            ch.send_data(stdin.to_s)
            ch.process
            ch.eof!
          end
        end
      end
    }
  end
end
