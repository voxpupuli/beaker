
class Action
  attr_accessor :host
  def initialize(host)
    @host = host
  end

  class Result
    attr_accessor :host, :cmd, :stdout, :stderr, :combined, :exit_code
    def initialize(host=nil, cmd=nil, stdout=nil, stderr=nil, combined=nil, exit_code=nil)
      @host      = host
      @cmd       = cmd
      @stdout    = stdout
      @stderr    = stderr
      @combined  = combined
      @exit_code = exit_code
    end
  end

  def do_action(*args)	
    usr_home=ENV['HOME']
    options={
      :config                => false,
      :paranoid              => false,
      :auth_methods          => ["publickey"],
      :keys                  => ["#{usr_home}/.ssh/id_rsa"],
      :port                  => 22,
      :user_known_hosts_file => "#{usr_home}/.ssh/known_hosts"
    }
    result = Result.new(host,args,'','','',0)
    if $dry_run
      puts "#{host}: #{self.class}(#{args.inspect})"
    else
      yield result,options
    end
    result
  end
end
