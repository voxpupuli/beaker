require 'yaml'

module Beaker
  module Options
    #An Object that parses, merges and normalizes all supported Beaker options and arguments
    class Parser
      GITREPO      = 'git://github.com/puppetlabs'
      #These options can have the form of arg1,arg2 or [arg] or just arg,
      #should default to []
      LONG_OPTS    = [:helper, :load_path, :tests, :pre_suite, :post_suite, :install, :pre_cleanup, :modules]
      #These options expand out into an array of .rb files
      RB_FILE_OPTS = [:tests, :pre_suite, :post_suite, :pre_cleanup]

      PARSE_ERROR = Psych::SyntaxError

      #The OptionsHash of all parsed options
      attr_accessor :options
      attr_reader :attribution

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
        if !paths.empty?
          paths.each do |root|
            @validator.validate_path(root)

            path_files = []
            if File.file?(root)
              path_files << root
            elsif File.directory?(root) #expand and explore
              path_files = Dir.glob(File.join(root, '**/*.rb'))
                               .select { |f| File.file?(f) }
                               .sort_by { |file| [file.count('/'), file] }
            end

            @validator.validate_files(path_files, root)
            files += path_files
          end
        end

        @validator.validate_files(files, paths.to_s)
        files
      end

      # resolves all file symlinks that require it. This modifies @options.
      #
      # @note doing it here allows us to not need duplicate logic, which we
      #   would need if we were doing it in the parser (--hosts & --config)
      #
      # @return nil
      # @api public
      def resolve_symlinks!
        if @options[:hosts_file] && !@options[:hosts_file_generated]
          @options[:hosts_file] = File.realpath(@options[:hosts_file])
        end
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
              opt = "#{repo}/puppet.git##{opt.split('/', 2)[1]}"
            when /^FACTER\//
              opt = "#{repo}/facter.git##{opt.split('/', 2)[1]}"
            when /^HIERA\//
              opt = "#{repo}/hiera.git##{opt.split('/', 2)[1]}"
            when /^HIERA-PUPPET\//
              opt = "#{repo}/hiera-puppet.git##{opt.split('/', 2)[1]}"
          end
          opt
        }
        git_opts
      end

      #Add the 'default' role to the host determined to be the default.  If a host already has the role default then
      #do nothing.  If more than a single host has the role 'default', raise error.
      #Default host determined to be 1) the only host in a single host configuration, 2) the host with the role 'master'
      #defined.
      #@param [Hash] hosts A hash of hosts, each identified by a String name.  Each named host will have an Array of roles
      def set_default_host!(hosts)
        default           = []
        master            = []
        default_host_name = nil

        #look through the hosts and find any hosts with role 'default' and any hosts with role 'master'
        hosts.each_key do |name|
          host = hosts[name]
          if host[:roles].include?('default')
            default << name
          elsif host[:roles].include?('master')
            master << name
          end
        end

        # default_set? will throw an error if length > 1
        # and return false if no default is set.
        if !@validator.default_set?(default)
          #no default set, let's make one
          if not master.empty? and master.length == 1
            default_host_name = master[0]
          elsif hosts.length == 1
            default_host_name = hosts.keys[0]
          end
          if default_host_name
            hosts[default_host_name][:roles] << 'default'
          end
        end
      end

      #Constructor for Parser
      #
      def initialize
        @command_line_parser = Beaker::Options::CommandLineParser.new
        @presets             = Beaker::Options::Presets.new
        @validator           = Beaker::Options::Validator.new
        @attribution         = Beaker::Options::OptionsHash.new
      end

      # Update the @attribution hash with the source of each key in the options_hash
      #
      # @param [Hash] options_hash Options hash 
      # @param [String] source Where the options were specified
      # @return [Hash] hash Hash of sources for each key
      def tag_sources(options_hash, source)
        hash = Beaker::Options::OptionsHash.new
        options_hash.each do |key, value|
          if value.is_a?(Hash)
            hash[key] = tag_sources(value, source)
          else
            hash[key] = source
          end
        end
        hash
      end

      # Update the @option hash with a value and the @attribution hash with a source
      #
      # @param [String] key The key to update in both hashes
      # @param [Object] value The value to set in the @options hash
      # @param [String] source The source to set in the @attribution hash
      def update_option(key, value, source)
        @options[key] = value
        @attribution[key] = source
      end

      # Parses ARGV or provided arguments array, file options, hosts options and combines with environment variables and
      # preset defaults to generate a Hash representing the Beaker options for a given test run
      #
      # Order of priority is as follows:
      #   1.  environment variables are given top priority
      #   2.  ARGV or provided arguments array
      #   3.  the 'CONFIG' section of the hosts file
      #   4.  options file values
      #   5.  subcommand options, if executing beaker subcommands
      #   6.  subcommand options from $HOME/.beaker/subcommand_options.yaml
      #   7.  default or preset values are given the lowest priority
      #
      # @param [Array] args ARGV or a provided arguments array
      # @raise [ArgumentError] Raises error on bad input
      def parse_args(args = ARGV)
        @options                        = @presets.presets
        @attribution = @attribution.merge(tag_sources(@presets.presets, "preset"))
        cmd_line_options                = @command_line_parser.parse(args)
        cmd_line_options[:command_line] = ([$0] + args).join(' ')
        @attribution = @attribution.merge(tag_sources(cmd_line_options, "flag"))

        # Global subcommand options from $HOME/.beaker/subcommand_options.yaml are first to get merged into presets
        homedir_options = Beaker::Options::SubcommandOptionsParser.parse_subcommand_options(args, ENV['HOME']+'/.beaker/subcommand_options.yaml')
        @attribution = @attribution.merge(tag_sources(homedir_options, "homedir"))
        @options.merge!(homedir_options)

        # Subcommands are the second to get merged into presets
        subcommand_options = Beaker::Options::SubcommandOptionsParser.parse_subcommand_options(args, Beaker::Subcommands::SubcommandUtil::SUBCOMMAND_OPTIONS)
        @attribution = @attribution.merge(tag_sources(subcommand_options, 'subcommand'))
        @options.merge!(subcommand_options)

        file_options                    = Beaker::Options::OptionsFileParser.parse_options_file(cmd_line_options[:options_file])
        @attribution = @attribution.merge(tag_sources(file_options, "options_file"))

        # merge together command line and file_options
        #   overwrite file options with command line options
        cmd_line_and_file_options       = file_options.merge(cmd_line_options)

        # merge command line and file options with defaults
        #   overwrite defaults with command line and file options
        @options                        = @options.merge(cmd_line_and_file_options)

        if not @options[:help] and not @options[:beaker_version_print]
          hosts_options = parse_hosts_options

          # merge in host file vars
          #   overwrite options (default, file options, command line) with host file options
          @options      = @options.merge(hosts_options)
          @attribution = @attribution.merge(tag_sources(hosts_options, "host_file"))

          # re-merge the command line options
          #   overwrite options (default, file options, hosts file ) with command line arguments
          @options      = @options.merge(cmd_line_options)
          @attribution = @attribution.merge(tag_sources(cmd_line_options, "cmd"))

          # merge in env vars
          #   overwrite options (default, file options, command line, hosts file) with env
          env_vars      = @presets.env_vars

          @options = @options.merge(env_vars)
          @attribution = @attribution.merge(tag_sources(env_vars, "env"))

          normalize_args
        end

        @options
      end

      # Parse hosts options from host files into a host options hash. Falls back
      # to trying as a beaker-hostgenerator string if reading the hosts file
      # doesn't work
      #
      # @return [Hash] Host options, containing all host-specific details
      # @raise [ArgumentError] if a hosts file is generated, but it can't
      #   be read by the HostsFileParser
      def parse_hosts_options
        if @options[:hosts_file].nil? || File.exists?(@options[:hosts_file])
          #read the hosts file that contains the node configuration and hypervisor info
          return Beaker::Options::HostsFileParser.parse_hosts_file(@options[:hosts_file])
        end

        dne_message = "\nHosts file '#{@options[:hosts_file]}' does not exist."
        dne_message << "\nTrying as beaker-hostgenerator input.\n\n"
        $stdout.puts dne_message
        require 'beaker-hostgenerator'

        hosts_file_content = begin
          bhg_cli = BeakerHostGenerator::CLI.new( [ @options[:hosts_file] ] )
          bhg_cli.execute
        rescue BeakerHostGenerator::Exceptions::Error,
          BeakerHostGenerator::Exceptions::InvalidNodeSpecError => error
          error_message = "\nbeaker-hostgenerator was not able to use this value as input."
          error_message << "\nExiting with an Error.\n\n"
          $stderr.puts error_message
          raise error
        end

        @options[:hosts_file_generated] = true
        Beaker::Options::HostsFileParser.parse_hosts_string( hosts_file_content )
      end

      #Validate all merged options values for correctness
      #
      #Currently checks:
      #  - each host has a valid platform
      #  - if a keyfile is provided then use it
      #  - paths provided to --test, --pre-suite, --post-suite provided lists of .rb files for testing
      #  - --fail-mode is one of 'fast', 'stop' or nil
      #  - if using blimpy hypervisor an EC2 YAML file exists
      #  - if using the aix, solaris, or vcloud hypervisors a .fog file exists
      #  - that one and only one master is defined per set of hosts
      #  - that solaris/windows/aix hosts are agent only for PE tests OR
      #  - sets the default host based upon machine definitions
      #  - if an ssh user has been defined make it the host user
      #
      #@raise [ArgumentError] Raise if argument/options values are invalid
      def normalize_args

        @options['HOSTS'].each_key do |name|
          @validator.validate_platform(@options['HOSTS'][name], name)
          @options['HOSTS'][name]['platform'] = Platform.new(@options['HOSTS'][name]['platform'])
        end

        #use the keyfile if present
        if @options.has_key?(:keyfile)
          @options[:ssh][:keys] = [@options[:keyfile]]
        end

        #split out arguments - these arguments can have the form of arg1,arg2 or [arg] or just arg
        #will end up being normalized into an array
        LONG_OPTS.each do |opt|
          if @options.has_key?(opt)
            update_option(opt, split_arg(@options[opt]), 'runtime')
            if RB_FILE_OPTS.include?(opt) && (not @options[opt] == [])
              update_option(opt, file_list(@options[opt]), 'runtime')
            end
            if opt == :install
              update_option(:install, parse_git_repos(@options[:install]), 'runtime')
            end
          else
            update_option(opt, [], 'runtime')
          end
        end

        @validator.validate_fail_mode(@options[:fail_mode])
        @validator.validate_preserve_hosts(@options[:preserve_hosts])

        #check for config files necessary for different hypervisors
        hypervisors = get_hypervisors(@options[:HOSTS])
        hypervisors.each do |visor|
          check_hypervisor_config(visor)
        end

        #check that roles of hosts make sense
        # - must be one and only one master
        master = 0
        roles  = get_roles(@options[:HOSTS])
        roles.each do |role_array|
          master += 1 if role_array.include?('master')
          @validator.validate_frictionless_roles(role_array)
        end

        @validator.validate_master_count(master)

        #check that windows/el-4 boxes are only agents (solaris can be a master in foss cases)
        @options[:HOSTS].each_key do |name|
          host = @options[:HOSTS][name]
          if host[:platform] =~ /windows|el-4/
            test_host_roles(name, host)
          end

          #check to see if a custom user account has been provided, if so use it
          if host[:ssh] && host[:ssh][:user]
            host[:user] = host[:ssh][:user]
          end

          # merge host tags for this host with the global/preset host tags
          host[:host_tags] = @options[:host_tags].merge(host[:host_tags] || {})
        end

        normalize_test_tags!
        @validator.validate_test_tags(
          @options[:test_tag_and],
          @options[:test_tag_or],
          @options[:test_tag_exclude]
        )
        resolve_symlinks!

        #set the default role
        set_default_host!(@options[:HOSTS])

      end

      # Get an array containing lists of roles by parsing each host in hosts.
      #
      # @param [Array<Array<String>>] hosts beaker hosts
      # @return [Array] roles [['master', 'database'], ['agent'], ...]
      def get_roles(hosts)
        roles = []
        hosts.each_key do |name|
          roles << hosts[name][:roles]
        end
        roles
      end

      # Get a unique list of hypervisors from list of host.
      #
      # @param [Array] hosts beaker hosts
      # @return [Array] unique list of hypervisors
      def get_hypervisors(hosts)
        hypervisors = []
        hosts.each_key { |name| hypervisors << hosts[name][:hypervisor].to_s }
        hypervisors.uniq
      end

      # Validate the config file for visor exists.
      #
      # @param [String] visor Hypervisor name
      # @return [nil] no return
      # @raise [ArgumentError] Raises error if config file does not exist or is not valid YAML
      def check_hypervisor_config(visor)
        if ['blimpy'].include?(visor)
          @validator.check_yaml_file(@options[:ec2_yaml], "required by #{visor}")
        end

        if %w(aix solaris vcloud).include?(visor)
          @validator.check_yaml_file(@options[:dot_fog], "required by #{visor}")
        end
      end

      # Normalize include and exclude tags. This modifies @options.
      #
      # @note refer to {Beaker::DSL::TestTagging} for test tagging implementation
      #
      def normalize_test_tags!
        @options[:test_tag_and]     ||= ''
        @options[:test_tag_or]      ||= ''
        @options[:test_tag_exclude] ||= ''
        @options[:test_tag_and]     = @options[:test_tag_and].split(',')     if @options[:test_tag_and].respond_to?(:split)
        @options[:test_tag_or]      = @options[:test_tag_or].split(',')      if @options[:test_tag_or].respond_to?(:split)
        @options[:test_tag_exclude] = @options[:test_tag_exclude].split(',') if @options[:test_tag_exclude].respond_to?(:split)
        @options[:test_tag_and].map!(&:downcase)
        @options[:test_tag_or].map!(&:downcase)
        @options[:test_tag_exclude].map!(&:downcase)
      end

      private

      # @api private
      def test_host_roles(host_name, host_hash)
        exclude_roles = %w(master database dashboard)
        host_roles    = host_hash[:roles]
        unless (host_roles & exclude_roles).empty?
          @validator.parser_error "#{host_hash[:platform].to_s} box '#{host_name}' may not have roles: #{exclude_roles.join(', ')}."
        end
      end

    end
  end
end
