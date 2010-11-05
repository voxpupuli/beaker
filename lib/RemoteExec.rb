# Remote command execution
# Accpets host name a remote command to execute
# Returns object "result"

class RemoteExec
  attr_accessor :host
  def initialize(host)
      self.host = host
  end

  class Result
    attr_accessor :host, :cmd, :output, :exit_code
    def initialize(host=nil, cmd=nil, output=nil, exit_code=nil)
      self.host      = host
      self.cmd       = cmd
      self.output    = output
      self.exit_code = exit_code
		end
  end

  def do_remote(cmd)	
    usr_home=ENV['HOME']
    options={
      :config                => false,
      :paranoid              => false,
      :auth_methods          => ["publickey"],
      :keys                  => ["#{usr_home}/.ssh/id_rsa"],
      :port                  => 22,
      :user_known_hosts_file => "#{usr_home}/.ssh/known_hosts"
    }
    result = Result.new

    Net::SSH.start("#{@host}", "root", options) do |ssh|
      ssh.open_channel do |channel|
        channel.exec(cmd) do |ch, success|
          unless success
            abort "FAILED: couldn't execute command (ssh.channel.exec failure)"
					end
        end 
        channel.on_data do |ch, data|  # stdout
          result.output = "#{data}"
        end
        channel.on_extended_data do |ch, type, data|
          next unless type == 1  # only handle stderr
          result.output = "#{data}"
        end
        channel.on_request("exit-status") do |ch, data|
          result.exit_code = data.read_long
        end
      end
    end
    return result
  end
end
