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

    # Should we send our logs to stdout?
    attr_accessor :stdout
    attr_accessor :color
    attr_reader   :file
    def file=(filename)
      if filename then
        @file = File.new(filename, "w")
      else
        @file = false
      end
    end

    def write
      yield $stdout if @stdout
      yield @file if @file
    end

    def debug(*args)
      return unless @log_level == :debug
      write do |to|
        to.print GREY if color
        to.puts *args
        to.print NORMAL if color
      end
    end

    def warn(*args)
      return unless @log_level == :debug
      write do |to|
        print YELLOW if color
        to.puts *args.map {|msg| "Warning: #{msg}"}
        print NORMAL if color
      end
    end

    def success(*args)
      write do |to|
        print GREEN if color
        to.puts *args.map {|msg| msg}
        print NORMAL if color
      end
    end

    def notify(*args)
      write do |to|
        to.puts *args
      end
    end

    def error(*args)
      write do |to|
        print BRIGHT_RED if color
        to.puts *args.map {|msg| "Error: #{msg}"}
        print NORMAL if color
      end
    end



    # utility method to get the current call stack and format it to a human-readable string (which some IDEs/editors
    # will recognize as links to the line numbers in the trace)
    def pretty_backtrace()

      caller(1).collect do |line|
        file_path, line_num = line.split(":")
        file_path = expand_symlinks(File.expand_path(file_path))

        file_path + ":" + line_num
      end .join("\n")

    end

    # utility method that takes a path as input, checks each component of the path to see if it is a symlink, and expands
    # it if it is.  returns the expanded path.
    def expand_symlinks(file_path)
      file_path.split("/").inject do |full_path, next_dir|
        next_path = full_path + "/" + next_dir
        if File.symlink?(next_path) then
          link = File.readlink(next_path)
          next_path =
              case link
                when /^\// then link
                else
                  File.expand_path(full_path + "/" + link)
              end
        end
        next_path
      end
    end
    private :expand_symlinks



  end
end
