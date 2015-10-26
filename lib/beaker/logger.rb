module Beaker
    # The Beaker Logger class
    # This class handles message reporting for Beaker, it reports based upon a provided log level
    # to a given destination (be it a string or file)
    #
  class Logger

    #The results of the most recently run command
    attr_accessor :last_result

    #Determines the spacing that happens before an output line
    attr_accessor :line_prefix

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
    GREY           = "\e[00;00m"  # Some terms can't handle grey, use normal
    BRIGHT_RED     = "\e[01;31m"
    BRIGHT_GREEN   = "\e[01;32m"
    BRIGHT_YELLOW  = "\e[01;33m"
    BRIGHT_BLUE    = "\e[01;34m"
    BRIGHT_MAGENTA = "\e[01;35m"
    BRIGHT_CYAN    = "\e[01;36m"
    BRIGHT_WHITE   = "\e[01;37m"
    NONE           = ""

    # The defined log levels.  Each log level also reports messages at levels lower than itself
    LOG_LEVELS      = {
      :trace   => 6,
      :debug   => 5,
      :verbose => 3,
      :info    => 2,
      :notify  => 1,
      :warn    => 0,
    }

    attr_accessor :color, :log_level, :destinations, :log_colors

    # Initialization of the Logger class
    # @overload initialize(dests)
    #   Initialize a Logger object that reports to the provided destinations, use default options
    #   @param [Array<String, IO>] Array of IO and strings (assumed to be file paths) to be reported to
    # @overload initialize(dests, options)
    #   Initialize a Logger object that reports to the provided destinations, use options from provided option hash
    #   @param [Array<String, IO>] Array of IO and strings (assumed to be file paths) to be reported to
    #   @param [Hash] options Hash of options
    #   @option options [Boolean] :color (true) Print color code before log messages
    #   @option options [Boolean] :quiet (false) Do not log messages to STDOUT
    #   @option options [String] :log_level ("info") Log level (one of "debug" - highest level, "verbose", "info",
    #                          "notify" and "warn" - lowest level (see {LOG_LEVELS}))  The log level indicates that messages at that
    #                          log_level and lower will be reported.
    def initialize(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      @color = options[:color]
      @sublog = nil
      case options[:log_level]
      when /trace/i, :trace
        @log_level = :trace
      when /debug/i, :debug
        @log_level = :debug
      when /verbose/i, :verbose
        @log_level = :verbose
      when /info/i, :info
        @log_level = :info
      when /notify/i, :notify
        @log_level = :notify
      when /warn/i, :warn
        @log_level = :warn
      else
        @log_level = :verbose
      end

      @last_result = nil
      @line_prefix_length = 0
      @line_prefix = ''

      @destinations = []

      @log_colors =  {
        :error => RED,
        :warn => BRIGHT_RED,
        :success => MAGENTA,
        :notify => BLUE,
        :info => GREEN,
        :debug => WHITE,
        :trace => BRIGHT_YELLOW,
        :perf => BRIGHT_MAGENTA,
        :host => YELLOW
      }

      @log_colors.merge!(options[:log_colors]) if options[:log_colors]

      # if a user overrides any of the log_colors, we will no longer
      # override the colors at all on a CI build. This is b/c it is
      # assumed that if a user is overriding the colors, they know
      # what they are doing. We could potentially add an additional
      # option a user can pass to be explicit about still allowing
      # the override.
      unless options[:log_colors]
        # Jenkins exposed variable - should be present on the slave directing
        # the beaker run
        ci_build = ENV['BUILD_NUMBER'] != nil

        @log_colors[:notify] = NORMAL if ci_build
        @log_colors[:info] = NORMAL if ci_build
      end

      dests = args
      dests << STDOUT unless options[:quiet]
      dests.uniq!
      dests.each {|dest| add_destination(dest)}
    end


    # Turn on/off STDOUT logging
    # @param [Boolean] off If true, disable STDOUT logging, if false enable STDOUT logging
    def quiet(off = true)
      if off
        remove_destination(STDOUT) #turn off the noise!
      else
        remove_destination(STDOUT) #in case we are calling this in error and we are already noisy
        add_destination(STDOUT)
      end
    end

    # Construct an array of open steams for printing log messages to
    # @param [Array<IO, String>] dest Array of strings (each used as a file path) and IO steams that messages will be printed to
    def add_destination(dest)
      case dest
      when IO
        @destinations << dest
      when StringIO
        @destinations << dest
      when String
        @destinations << File.open(dest, 'w')
      else
        raise "Unsuitable log destination #{dest.inspect}"
      end
    end

    # Remove a steam from the destinations array based upon it's name or file path
    # @param [String, IO] dest String representing a file path or IO stream
    def remove_destination(dest)
      case dest
      when IO
        @destinations.delete(dest)
      when StringIO
        @destinations.delete(dest)
      when String
        @destinations.delete_if {|d| d.respond_to?(:path) and d.path == dest}
      else
        raise "Unsuitable log destination #{dest.inspect}"
      end
    end

    # Are we at {LOG_LEVELS} trace?
    # @return [Boolean] true if 'trace' or higher, false if not 'trace' {LOG_LEVELS} or lower
    def is_trace?
      LOG_LEVELS[@log_level] >= LOG_LEVELS[:trace]
    end

    # Are we at {LOG_LEVELS} debug?
    # @return [Boolean] true if 'debug' or higher, false if not 'debug' {LOG_LEVELS} or lower
    def is_debug?
      LOG_LEVELS[@log_level] >= LOG_LEVELS[:debug]
    end

    # Are we at {LOG_LEVELS} verbose?
    # @return [Boolean] true if 'verbose' or higher, false if not 'verbose' {LOG_LEVELS} or lower
    def is_verbose?
      LOG_LEVELS[@log_level] >= LOG_LEVELS[:verbose]
    end

    # Are we at {LOG_LEVELS} warn?
    # @return [Boolean] true if 'warn' or higher, false if not 'warn' {LOG_LEVELS} or lower
    def is_warn?
      LOG_LEVELS[@log_level] >= LOG_LEVELS[:warn]
    end

    # Are we at {LOG_LEVELS} info?
    # @return [Boolean] true if 'info' or higher, false if not 'info' {LOG_LEVELS} or lower
    def is_info?
      LOG_LEVELS[@log_level] >= LOG_LEVELS[:info]
    end

    # Are we at {LOG_LEVELS} notify?
    # @return [Boolean] true if 'notify' or higher, false if not 'notify' {LOG_LEVELS} or lower
    def is_notify?
      LOG_LEVELS[@log_level] >= LOG_LEVELS[:notify]
    end

    # Remove invalid UTF-8 codes from provided string(s)
    # @param [String, Array<String>] string The string(s) to remove invalid codes from
    def convert string
      if string.kind_of?(Array)
        string.map do |s|
          convert s
        end
      else
        # Remove invalid and undefined UTF-8 character encodings
        string.to_s.force_encoding('UTF-8')
        return string.to_s.chars.select{|i| i.valid_encoding?}.join
      end
    end

    # Prefixes a log line with the appropriate amount of whitespace for the level
    # of test that's running.
    #
    # @param [String] line the line to prefix
    #
    # @return [String] the prefixed line
    def prefix_log_line line
      if line.kind_of?(Array)
        line.map do |s|
          prefix_log_line s
        end
      else
        line.gsub!(/\r/, '')
        has_ending_newline = line.end_with?("\n")
        actual_lines = line.split("\n")
        actual_lines.map! do |actual_line|
          @line_prefix + actual_line
        end
        new_line = actual_lines.join("\n")
        new_line << "\n" if has_ending_newline
        new_line
      end
    end

    # Sets the step level appropriately for logging to be indented correctly
    #
    # @return nil
    def step_in
      @line_prefix_length += 2
      @line_prefix = ' ' * @line_prefix_length
    end

    # Sets the step level appropriately for logging to be indented correctly
    #
    # @return nil
    def step_out
      @line_prefix_length -= 2
      @line_prefix_length = 0 if @line_prefix_length < 0
      @line_prefix = ' ' * @line_prefix_length
    end

    # Custom reporting for messages generated by host SUTs.
    # Will not print unless we are at {LOG_LEVELS} 'verbose' or higher.
    # Strips any color codes already in the provided messages, then adds logger color codes before reporting
    # @param args[Array<String>] Strings to be reported
    def host_output *args
      return unless is_verbose?
      strings = strip_colors_from args
      string = strings.join
      optionally_color @log_colors[:host], string, false
    end

    # Custom reporting for messages generated by host SUTs - to preserve output
    # Will not print unless we are at {LOG_LEVELS} 'verbose' or higher.
    # Preserves outout by not stripping out colour codes
    # @param args[Array<String>] Strings to be reported
    def color_host_output *args
      return unless is_verbose?
      string = args.join
      optionally_color NONE, string, false
    end

    # Custom reporting for performance/sysstat messages
    # Will not print unless we are at {LOG_LEVELS} 'debug' or higher.
    # @param args[Array<String>] Strings to be reported
    def perf_output *args
      return unless is_debug?
      optionally_color @log_colors[:perf], *args
    end

    # Report a trace message.
    # Will not print unless we are at {LOG_LEVELS} 'trace' or higher.
    # @param args[Array<String>] Strings to be reported
    def trace *args
      return unless is_trace?
      optionally_color @log_colors[:trace], *args
    end

    # Report a debug message.
    # Will not print unless we are at {LOG_LEVELS} 'debug' or higher.
    # @param args[Array<String>] Strings to be reported
    def debug *args
      return unless is_verbose?
      optionally_color @log_colors[:debug], *args
    end

    # Report a warning message.
    # Will not print unless we are at {LOG_LEVELS} 'warn' or higher.
    # Will pre-pend the message with "Warning: ".
    # @param args[Array<String>] Strings to be reported
    def warn *args
      return unless is_warn?
      strings = args.map {|msg| "Warning: #{msg}" }
      optionally_color @log_colors[:warn], strings
    end

    # Report an info message.
    # Will not print unless we are at {LOG_LEVELS} 'info' or higher.
    # @param args[Array<String>] Strings to be reported
    def info *args
      return unless is_info?
      optionally_color @log_colors[:info], *args
    end

    # Report a success message.
    # Will always be reported.
    # @param args[Array<String>] Strings to be reported
    def success *args
      optionally_color @log_colors[:success], *args
    end

    # Report a notify message.
    # Will not print unless we are at {LOG_LEVELS} 'notify' or higher.
    # @param args[Array<String>] Strings to be reported
    def notify *args
      return unless is_notify?
      optionally_color @log_colors[:notify], *args
    end

    # Report an error message.
    # Will always be reported.
    # @param args[Array<String>] Strings to be reported
    def error *args
      optionally_color @log_colors[:error], *args
    end

    # Strip any color codes from provided string(s)
    # @param [String] lines A single or array of lines to removed color codes from
    # @return [Array<String>] An array of strings that do not have color codes
    def strip_colors_from lines
      Array( lines ).map do |line|
        Logger.strip_color_codes(convert(line))
      end
    end

    # Print the provided message to the set destination streams, using color codes if appropriate
    # @param [String] color_code The color code to pre-pend to the message
    # @param [String] msg The message to be reported
    # @param [Boolean] add_newline (true) Add newlines between the color codes and the message
    def optionally_color color_code, msg, add_newline = true
      print_statement = add_newline ? :puts : :print
      msg = convert(msg)
      msg = prefix_log_line(msg)
      @destinations.each do |to|
        to.print color_code if @color
        to.send print_statement, msg
        to.print NORMAL if @color unless color_code == NONE
      end
    end

    # Utility method to get the current call stack and format it
    # to a human-readable string (which some IDEs/editors
    # will recognize as links to the line numbers in the trace).
    # Beaker associated files will be purged from backtrace unless log level is 'debug' or higher
    # @param [String] backtrace (caller(1)) The backtrace to format
    # @return [String] The formatted backtrace
    def pretty_backtrace backtrace = caller(1)
      trace = is_debug? ? backtrace : purge_harness_files_from( backtrace )
      expand_symlinks( trace ).join "\n"
    end

    # Create a new StringIO log to track the current output
    def start_sublog
      if @sublog
        remove_destination(@sublog)
      end
      @sublog = StringIO.new
      add_destination(@sublog)
    end

    # Return the contents of the sublog
    def get_sublog
      @sublog.rewind
      @sublog.read
    end

    # Utility method to centralize dated log folder generation
    #
    # @param [String] base_dir Path of the directory for the dated log folder to live in
    # @param [String] log_prefix Prefix to use for the log files
    # @param [Time] timestamp Timestamp that should be used to generate the dated log folder
    #
    # @example base_dir = 'junit', log_prefix = 'pants', timestamp = '2015-03-04 10:35:37 -0800'
    #   returns 'junit/pants/2015-03-04_10_35_37'
    #
    # @note since this uses 'mkdir -p', log_prefix can be a number of nested directories
    #
    # @return [String] the path of the dated log folder generated
    def Logger.generate_dated_log_folder(base_dir, log_prefix, timestamp)
      log_dir = File.join(base_dir, log_prefix, timestamp.strftime("%F_%H_%M_%S"))
      FileUtils.mkdir_p(log_dir) unless File.directory?(log_dir)
      log_dir
    end

    #Remove color codes from provided string.  Color codes are of the format /(\e\[\d\d;\d\dm)+/.
    #@param [String] text The string to remove color codes from
    #@return [String] The text without color codes
    def Logger.strip_color_codes(text)
      text.gsub(/(\e|\^\[)\[(\d*;)*\d*m/, '')
    end

    private
    # Expand each symlink found to its full path
    # Lines are assumed to be in the format "String : Integer"
    # @param [String] backtrace The string to search and expand symlinks in
    # @return [String] The backtrace with symlinks expanded
    def expand_symlinks backtrace
      backtrace.collect do |line|
        file_path, line_num = line.split( ":" )
        expanded_path = expand_symlink File.expand_path( file_path )
        expanded_path.to_s + ":" + line_num.to_s
      end
    end

    # Remove Beaker associated lines from a given String
    # @param [String] backtrace The string to remove Beaker associated lines from
    # @return [String] The cleaned backtrace
    def purge_harness_files_from backtrace
      mostly_purged = backtrace.reject do |line|
        # LOADED_FEATURES is an array of anything `require`d, i.e. everything
        # but the test in question
        $LOADED_FEATURES.any? do |require_path|
          line.include? require_path
        end
      end

      # And remove lines that contain our program name in them
      completely_purged = mostly_purged.reject {|line| line.include? $0 }
    end

    # Utility method that takes a path as input, checks each component
    # of the path to see if it is a symlink, and expands
    # it if it is.
    # @param [String] file_path The path to be examined
    # @return [String] The fully expanded file_path
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
