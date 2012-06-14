module PuppetAcceptance
  class Logger
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

    attr_accessor :log_level

    # Should we send our logs to stdout?
    attr_accessor :color

    def file=(filename)
      if filename then
        @file = File.new(filename, "w")
      else
        @file = false
      end
    end

    def initialize(*dests)
      @destinations = []
      dests.each {|dest| add_destination(dest)}

      @log_level = :normal
      @color = true
    end

    def add_destination(dest)
      case dest
      when IO
        @destinations << dest
      when String
        @destinations << File.open(dest, 'w')
      else
        raise "Unsuitable log destination #{dest.inspect}"
      end
    end

    def remove_destination(dest)
      case dest
      when IO
        @destinations.delete(dest)
      when String
        @destinations.delete_if {|d| d.respond_to?(:path) and d.path == dest}
      else
        raise "Unsuitable log destination #{dest.inspect}"
      end
    end

    def debug(*args)
      return unless @log_level == :debug
      @destinations.each do |to|
        to.print GREY if color
        to.puts *args
        to.print NORMAL if color
      end
    end

    # This is almost exactly the same as debug, except with slightly different
    # semantics. It's used exclusively for logging command output received from
    # a host, which may be done differently depending on success/failure/debug.
    # Also, we want to `print` rather than `puts`, lest we receive partial
    # output.
    def host_output(*args)
      return unless @log_level == :debug

      # Strip colors for readability.
      strings = args.map do |arg|
        arg.gsub(/\e\[(\d+;)?\d+m/, '')
      end
      @destinations.each do |to|
        to.print GREY if color
        to.print *strings
        to.print NORMAL if color
      end
    end

    def warn(*args)
      return unless @log_level == :debug
      @destinations.each do |to|
        to.print YELLOW if color
        to.puts *args.map {|msg| "Warning: #{msg}"}
        to.print NORMAL if color
      end
    end

    def success(*args)
      @destinations.each do |to|
        to.print GREEN if color
        to.puts *args.map {|msg| msg}
        to.print NORMAL if color
      end
    end

    def notify(*args)
      @destinations.each do |to|
        to.puts *args
      end
    end

    def error(*args)
      @destinations.each do |to|
        to.print BRIGHT_RED if color
        to.puts *args.map {|msg| "Error: #{msg}"}
        to.print NORMAL if color
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
