class Result
  attr_accessor :host, :cmd, :stdout, :stderr, :exit_code
  def initialize(host=nil, cmd=nil, stdout=nil, stderr=nil, exit_code=nil)
    @host      = host
    @cmd       = cmd
    @stdout    = stdout
    @stderr    = stderr
    @exit_code = exit_code
  end

  def log(test_name)
    puts "<STDOUT>\n#{stdout}\n</STDOUT>"
    puts "<STDERR>\n#{stderr}\n</STDERR>"
    puts "Exited with #{exit_code}"
    puts
  end
end
