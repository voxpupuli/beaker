class Result
  attr_accessor :host, :cmd, :stdout, :stderr, :exit_code
  def initialize(host=nil, cmd=nil, stdout=nil, stderr=nil, exit_code=nil)
    @host      = host
    @cmd       = cmd
    @stdout    = stdout
    @stderr    = stderr
    @exit_code = exit_code
  end
  def self.ad_hoc(host,message,exit_code)
    new(host,'',message,nil,exit_code)
  end
  def combined
    "#{stdout}#{stderr}"
  end
  def explicit_empty(s)
    (s == '') ? "<empty>" : s
  end
  def log(test_name)
    puts "OUTPUT (stdout, stderr, exitcode):"
    puts explicit_empty(stdout)
    puts explicit_empty(stderr)
    puts exit_code
    puts "RESULT*** TEST:#{test_name} STATUS:#{(exit_code == 0) ? 'PASSED' : 'FAILED'} on HOST:#{host}"
  end
end
