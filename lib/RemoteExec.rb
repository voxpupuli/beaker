# Remote command execution
# Accpets host name a remote command to execute
# Returns object "result"
require 'lib/action'

class RemoteExec < Action
  def do_remote(cmd)	
    do_action(cmd) { |result,options|
      Net::SSH.start(host, "root", options) do |ssh|
        ssh.open_channel do |channel|
          channel.exec(cmd) do |ch, success|
            abort "FAILED: couldn't execute command (ssh.channel.exec failure)" unless success
          end 
          channel.on_data { |ch, data| result.stdout << data }
          channel.on_extended_data { |ch, type, data| result.stderr << data if type == 1 }
          channel.on_request("exit-status") { |ch, data| result.exit_code = data.read_long }
        end
      end
    }
  end
end
