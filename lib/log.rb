class Log
  NORMAL         = "\e[00;00m"
  BRIGHT_NORMAL  = "\e[00;01m"
  BLACK          = "\e[00;30m"
  RED            = "\e[00;31m"
  GREEN          = "\e[00;32m"
  YELLOW         = "\e[00;33m"
  BLUE           = "\e[00;34m"
  MAGENTA        = "\e[00;35m"
  CYAN           = "\e[00;36m"
  WHITE          = "\e[00;37m"
  GREY           = "\e[01;30m"
  BRIGHT_RED     = "\e[01;31m"
  BRIGHT_GREEN   = "\e[01;32m"
  BRIGHT_YELLOW  = "\e[01;33m"
  BRIGHT_BLUE    = "\e[01;34m"
  BRIGHT_MAGENTA = "\e[01;35m"
  BRIGHT_CYAN    = "\e[01;36m"
  BRIGHT_WHITE   = "\e[01;37m"

  class << self
    attr_accessor :log_level
    @log_level = :normal

    def debug(*args)
      return unless @log_level == :debug
      print GREY
      puts *args
      print NORMAL
    end

    def warn(*args)
      return unless @log_level == :debug
      print YELLOW
      puts *args.map {|msg| "Warning: #{msg}"}
      print NORMAL
    end

    def notify(*args)
      puts *args
    end

    def error(*args)
      print BRIGHT_RED
      puts *args.map {|msg| "Error: #{msg}"}
      print NORMAL
    end
  end
end
