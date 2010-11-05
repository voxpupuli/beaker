# SCP file to host
class ScpFile
  attr_accessor :host
  def initialize(host)
      self.host   = host
  end

  class Result
    attr_accessor :host, :cmd, :stdout, :stderr, :exit_code
    def initialize(host=nil, cmd=nil, stdout=nil, stderr=nil, exit_code=nil)
      self.host      = host
      self.cmd       = cmd
      self.stdout    = stdout
      self.stderr    = stderr
      self.exit_code = exit_code
		end
  end

  def do_scp(source, target)
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
    # Net::Scp always returns 0, so just set the return code to 0
    # Setting these values allows reporting via 
    # ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
    result.stdout = "SCP'ed #{@host}/#{@source} #{@target}"
    result.stderr = nil
    result.exit_code = 0
	
    if Net::SCP.start("#{@host}", "root", options) do |scp|
          scp.upload!("#{source}", "#{target}")
        end
    end
    return result
  end
end

#self.source = source 
#self.target = target 
#self.exit_code = exit_code
