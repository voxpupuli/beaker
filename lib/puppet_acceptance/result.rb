module PuppetAcceptance
  class Result
    attr_accessor :host, :cmd, :stdout, :stderr, :exit_code, :output
    def initialize(host = nil, cmd = nil, stdout = '', stderr = '',
                   exit_code = nil, output = '')
      @host      = host
      @cmd       = cmd
      @stdout    = stdout
      @stderr    = stderr
      @exit_code = exit_code
      @output    = output
    end

    def log
      Log.debug
      Log.debug "<STDOUT>\n#{host}: #{stdout}\n</STDOUT>"
      Log.debug "<STDERR>\n#{host}: #{stderr}\n</STDERR>"
      Log.debug "#{host}: Exited with #{exit_code}"
    end

    def formatted_output
      limit = 10
      @output.split("\n").last(limit).collect {|x| "\t" + x}.join("\n")
    end

    def exit_code_in?(range)
      range.include?(@exit_code)
    end
  end
end
