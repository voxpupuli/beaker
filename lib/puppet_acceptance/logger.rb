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

    LOG_LEVELS      = {
      :debug  => 1,
      :warn   => 2,
      :normal => 3,
      :info   => 4
    }

    attr_accessor :color, :log_level, :destinations

    def initialize(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      @color = options[:color]
      @log_level = options[:debug] ? :debug : :normal
      @destinations = []

      dests = args
      dests << STDOUT unless options[:quiet]
      dests.uniq!
      dests.each {|dest| add_destination(dest)}
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

    def is_debug?
      LOG_LEVELS[@log_level] <= LOG_LEVELS[:debug]
    end

    def is_warn?
      LOG_LEVELS[@log_level] <= LOG_LEVELS[:warn]
    end

    def host_output *args
      return unless is_debug?
      strings = strip_colors_from args
      string = strings.join
      optionally_color GREY, string, false
    end

    def debug *args
      return unless is_debug?
      optionally_color WHITE, args
    end

    def warn *args
      return unless is_warn?
      strings = args.map {|msg| "Warning: #{msg}" }
      optionally_color YELLOW, strings
    end

    def success *args
      optionally_color GREEN, args
    end

    def notify *args
      optionally_color BRIGHT_WHITE, args
    end

    def error *args
      optionally_color BRIGHT_RED, args
    end

    def strip_colors_from lines
      Array(lines).map do |line|
        line.gsub /\e\[(\d+;)?\d+m/, ''
      end
    end

    def optionally_color color_code, msg, add_newline = true
      print_statement = add_newline ? :puts : :print
      @destinations.each do |to|
        to.print color_code if @color
        to.send print_statement, msg
        to.print NORMAL if @color
      end
    end

    # utility method to get the current call stack and format it
    # to a human-readable string (which some IDEs/editors
    # will recognize as links to the line numbers in the trace)
    def pretty_backtrace backtrace = caller(1)
      backtrace = purge_harness_files_from( backtrace ) if is_debug?
      expand_symlinks( backtrace ).join "\n"
    end

   private
    def expand_symlinks backtrace
      backtrace.collect do |line|
        file_path, line_num = line.split( ":" )
        expanded_path = expand_symlink File.expand_path( file_path )
        expanded_path + ":" + line_num
      end
    end

    def purge_harness_files_from backtrace
      mostly_purged = backtrace.reject do |line|
        $".any? do |require_path|
          line.include? require_path
        end
      end
      completely_purged = mostly_purged.reject {|line| line.include? $0 }
    end

    # utility method that takes a path as input, checks each component
    # of the path to see if it is a symlink, and expands
    # it if it is.  returns the expanded path.
    def expand_symlink file_path
      file_path.split( "/" ).inject do |full_path, next_dir|
        next_path = full_path + "/" + next_dir
        if File.symlink? next_path
          link = File.readlink next_path
          next_path =
              case link
                when /^\// then link
                else
                  File.expand_path( full_path + "/" + link )
              end
        end
        next_path
      end
    end
  end
end
