module Beaker
  module Options
    #An Object that parses, merges and normalizes all supported Beaker options and arguments
    class Parser
      GITREPO      = 'git://github.com/puppetlabs'
      #These options can have the form of arg1,arg2 or [arg] or just arg, 
      #should default to []
      LONG_OPTS    = [:helper, :load_path, :tests, :pre_suite, :post_suite, :install, :modules]
      #These options expand out into an array of .rb files
      RB_FILE_OPTS = [:tests, :pre_suite, :post_suite]
      #The OptionsHash of all parsed options
      attr_accessor :options

      # Raises an ArgumentError with associated message
      # @param [String] msg The error message to be reported
      # @raise [ArgumentError] Takes the supplied message and raises it as an ArgumentError
      def parser_error msg = ""
        raise ArgumentError, msg.to_s
      end

      # Returns the git repository used for git installations
      # @return [String] The git repository
      def repo
        GITREPO
      end

      # Returns a description of Beaker's supported arguments
      # @return [String] The usage String
      def usage
       @command_line_parser.usage
      end

      # Normalizes argument into an Array.  Argument can either be converted into an array of a single value,
      # or can become an array of multiple values by splitting arg over ','.  If argument is already an
      # array that array is returned untouched.
      # @example
      #   split_arg([1, 2, 3]) == [1, 2, 3] 
      #   split_arg(1) == [1]
      #   split_arg("1,2") == ["1", "2"]
      #   split_arg(nil) == []
      # @param [Array, String] arg Either an array or a string to be split into an array
      # @return [Array] An array of the form arg, [arg], or arg.split(',')
      def split_arg arg
        arry = []
        if arg.is_a?(Array)
          arry += arg
        elsif arg =~ /,/
          arry += arg.split(',')
        else
          arry << arg
        end
        arry
      end

      # Generates a list of files based upon a given path or list of paths.
      #
      # Looks recursively for .rb files in paths.
      #
      # @param [Array] paths Array of file paths to search for .rb files
      # @return [Array] An Array of fully qualified paths to .rb files
      # @raise [ArgumentError] Raises if no .rb files are found in searched directory or if
      #                         no .rb files are found overall
      def file_list(paths)
        files = []
        if not paths.empty?
          paths.each do |root|
            if File.file? root then
              files << root
            else
              discover_files = Dir.glob(
                File.join(root, "**/*.rb")
              ).select { |f| File.file?(f) }
              if discover_files.empty?
                parser_error "empty directory used as an option (#{root})!"
              end
              files += discover_files
            end
          end
        end
        if files.empty?
          parser_error "no .rb files found in #{paths.to_s}"
        end
        files
      end

      #Converts array of paths into array of fully qualified git repo URLS with expanded keywords
      #
      #Supports the following keywords
      #  PUPPET 
      #  FACTER
      #  HIERA 
      #  HIERA-PUPPET
      #@example
      #  opts = ["PUPPET/3.1"]
      #  parse_git_repos(opts) == ["#{GITREPO}/puppet.git#3.1"]
      #@param [Array] git_opts An array of paths
      #@return [Array] An array of fully qualified git repo URLs with expanded keywords
      def parse_git_repos(git_opts)
        git_opts.map! { |opt|
          case opt
            when /^PUPPET\//
              opt = "#{GITREPO}/puppet.git##{opt.split('/', 2)[1]}"
            when /^FACTER\//
              opt = "#{GITREPO}/facter.git##{opt.split('/', 2)[1]}"
            when /^HIERA\//
              opt = "#{GITREPO}/hiera.git##{opt.split('/', 2)[1]}"
            when /^HIERA-PUPPET\//
              opt = "#{GITREPO}/hiera-puppet.git##{opt.split('/', 2)[1]}"
          end
          opt
        }
        git_opts
      end

      #Constructor for Parser
      #
      def initialize
         @command_line_parser = Beaker::Options::CommandLineParser.new
      end

      # Parses ARGV or provided arguments array, file options, hosts options and combines with environment variables and
      # preset defaults to generate a Hash representing the Beaker options for a given test run
      #
      # Order of priority is as follows:
      #   1.  environment variables are given top priority
      #   2.  host file options
      #   3.  the 'CONFIG' section of the hosts file
      #   4.  ARGV or provided arguments array
      #   5.  options file values
      #   6.  default or preset values are given the lowest priority
      #
      # @param [Array] args ARGV or a provided arguments array
      # @raise [ArgumentError] Raises error on bad input
      def parse_args(args = ARGV)
        #NOTE on argument precedence:
        #
        # Will use env, then hosts/config file, then command line, then file options
        # 
        @options = Beaker::Options::Presets.presets
        cmd_line_options = @command_line_parser.parse!(args)
        file_options = Beaker::Options::OptionsFileParser.parse_options_file(cmd_line_options[:options_file])
        # merge together command line and file_options
        #   overwrite file options with command line options
        cmd_line_and_file_options = file_options.merge(cmd_line_options)
        # merge command line and file options with defaults
        #   overwrite defaults with command line and file options 
        @options = @options.merge(cmd_line_and_file_options)

        #read the hosts file that contains the node configuration and hypervisor info
        hosts_options = Beaker::Options::HostsFileParser.parse_hosts_file(@options[:hosts_file])
        # merge in host file vars
        #   overwrite options (default, file options, command line, env) with host file options
        @options = @options.merge(hosts_options)
        # merge in env vars
        #   overwrite options (default, file options, command line, hosts file) with env
        env_vars = Beaker::Options::Presets.env_vars
        @options = @options.merge(env_vars)

        if @options.is_pe?
          @options['HOSTS'].each_key do |name, val| 
            if @options['HOSTS'][name]['platform'] =~ /windows/ 
              @options['HOSTS'][name]['pe_ver_win'] = @options['HOSTS'][name]['pe_ver_win'] || Beaker::Options::PEVersionScraper.load_pe_version(
                                   @options['HOSTS'][name][:pe_dir] || @options[:pe_dir], @options[:pe_version_file_win])
            else
              @options['HOSTS'][name]['pe_ver'] = @options['HOSTS'][name]['pe_ver'] || Beaker::Options::PEVersionScraper.load_pe_version(
                                   @options['HOSTS'][name][:pe_dir] || @options[:pe_dir], @options[:pe_version_file])
            end
          end
        else
          @options['puppet_ver']       = @options[:puppet]
          @options['facter_ver']       = @options[:facter]
          @options['hiera_ver']        = @options[:hiera]
          @options['hiera_puppet_ver'] = @options[:hiera_puppet]
        end

        normalize_args

        @options

      end

      # Determine is a given file exists and is a valid YAML file
      # @param [String] f The YAML file path to examine
      # @param [String] msg An options message to report in case of error
      # @raise [ArgumentError] Raise if file does not exist or is not valid YAML
      def check_yaml_file(f, msg = "")
        if not File.file?(f)
          parser_error "#{f} does not exist (#{msg})"
        end
        begin
          YAML.load_file(f)
        rescue Psych::SyntaxError => e
          parser_error "#{f} is not a valid YAML file (#{msg})\n\t#{e}"
        end
      end

      #Validate all merged options values for correctness
      #
      #Currently checks:
      #  - paths provided to --test, --pre-suite, --post-suite provided lists of .rb files for testing
      #  - --type is one of 'pe' or 'git'
      #  - --fail-mode is one of 'fast', 'stop' or nil
      #  - if using blimpy hypervisor an EC2 YAML file exists
      #  - if using the aix, solaris, or vcloud hypervisors a .fog file exists
      #  - that one and only one master is defined per set of hosts
      #  - that solaris/windows/aix hosts are agent only
      #
      #@raise [ArgumentError] Raise if argument/options values are invalid
      def normalize_args

        #split out arguments - these arguments can have the form of arg1,arg2 or [arg] or just arg
        #will end up being normalized into an array
        LONG_OPTS.each do |opt|
          if @options.has_key?(opt)
            @options[opt] = split_arg(@options[opt])
            if RB_FILE_OPTS.include?(opt)
              @options[opt] = file_list(@options[opt])
            end
            if opt == :install
              @options[:install] = parse_git_repos(@options[:install])
            end
          else
            @options[opt] = []
          end
        end 
 
        #check for valid type
        if @options[:type] !~ /(pe)|(git)/
          parser_error "--type must be one of pe or git, not '#{@options[:type]}'"
        end

        #check for valid fail mode
        if not ["fast", "stop", nil].include?(@options[:fail_mode])
          parser_error "--fail-mode must be one of fast, stop" 
        end

        #check for config files necessary for different hypervisors
        hypervisors = [] 
        @options[:HOSTS].each_key do |name|  
          hypervisors << @options[:HOSTS][name][:hypervisor].to_s
        end
        hypervisors.uniq!
        hypervisors.each do |visor|
          if ['blimpy'].include?(visor)
            check_yaml_file(@options[:ec2_yaml], "required by #{visor}")
          end
          if ['aix', 'solaris', 'vcloud'].include?(visor)
            check_yaml_file(@options[:dot_fog], "required by #{visor}")
          end
        end

        #check that roles of hosts make sense
        # - must be one and only one master
        roles = []
        @options[:HOSTS].each_key do |name|  
          roles << @options[:HOSTS][name][:roles]
        end
        master = 0
        roles.each do |role_array|
          if role_array.include?('master')
            master += 1
          end
        end
        if master > 1 or master < 1
          parser_error "One and only one host/node may have the role 'master', fix #{@options[:hosts_file]}"
        end

        #check that solaris/windows/el-4 boxes are only agents
        @options[:HOSTS].each_key do |name|
          if @options[:HOSTS][name][:platform] =~ /(solaris)|(windows)|(el-4)/
             if (@options[:HOSTS][name][:roles] - ['agent']).size != 0
               parser_error "#{@options[:HOSTS][name][:platform].to_s} box '#{name}' can only have role 'agent', has roles #{@options[:HOSTS][name][:roles].to_s}"
             end
          end
        end

      end

    end
  end
end
