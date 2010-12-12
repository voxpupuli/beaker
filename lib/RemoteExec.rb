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
          channel.on_data do |ch, data|  # stdout
            result.stdout << data
            result.combined << data
          end
          channel.on_extended_data do |ch, type, data|
            next unless type == 1  # only handle stderr
            result.stderr << data
	    result.combined << data
          end
          channel.on_request("exit-status") do |ch, data|
            result.exit_code = data.read_long
          end
        end
      end
    }
  end
end
