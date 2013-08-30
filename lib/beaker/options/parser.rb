module Beaker
  module Options
    class Parser
      GITREPO      = 'git://github.com/puppetlabs'
      #these options can have the form of arg1,arg2 or [arg] or just arg
      #should default to []
      LONG_OPTS    = [:helper, :load_path, :tests, :pre_suite, :post_suite, :install, :modules]
      #these options expand out into an array of .rb files
      RB_FILE_OPTS = [:tests, :pre_suite, :post_suite]
      attr_accessor :options

      def parser_error msg = ""
        raise ArgumentError, msg.to_s
      end

      def repo
        GITREPO
      end

      #split given argument into an array
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

      #generates a list of files based upon a given path or list of paths
      #looks for .rb files
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

      def initialize
         @command_line_parser = Beaker::Options::CommandLineParser.new
      end

      def parse_args
        #NOTE on argument precedence:
        #
        # Will use env, then hosts/config file, then command line, then file options
        # 
        @options = Beaker::Options::Presets.presets
        cmd_line_options = @command_line_parser.parse!
        file_options = parse_options_file(cmd_line_options[:options_file])
        # merge together command line and file_options
        #   overwrite file options with command line options
        cmd_line_and_file_options = file_options.merge(cmd_line_options)
        # merge command line and file options with defaults
        #   overwrite defaults with command line and file options 
        @options = @options.merge(cmd_line_and_file_options)

        #read the hosts file that contains the node configuration and hypervisor info
        pre_validate_args
        hosts_options = parse_hosts_file(@options[:hosts_file])
        # merge in host file vars
        #   overwrite options (default, file options, command line, env) with host file options
        @options = @options.merge(hosts_options)
        # merge in env vars
        #   overwrite options (default, file options, command line, hosts file) with env
        env_vars = Beaker::Options::Presets.env_vars
        @options = @options.merge(env_vars)

        if @options.is_pe?
          @options['pe_ver']           = Beaker::Options::PEVersionScraper.load_pe_version(@options[:pe_dir], @options[:pe_version_file])
          @options['pe_ver_win']       = Beaker::Options::PEVersionScraper.load_pe_version(@options[:pe_dir], @options[:pe_version_file_win])
        else
          @options['puppet_ver']       = @options[:puppet]
          @options['facter_ver']       = @options[:facter]
          @options['hiera_ver']        = @options[:hiera]
          @options['hiera_puppet_ver'] = @options[:hiera_puppet]
        end

        validate_args

        @options

      end

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

      #validation done after all option parsing
      def validate_args

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

      end

      #validation done before parsing host file options
      def pre_validate_args
        #ensure that a host files has been provided and is correctly formatted
        check_yaml_file(@options[:hosts_file], "required host/node configuration information")
      end

      def parse_options_file(options_file_path)
        result = Beaker::Options::OptionsHash.new
        if options_file_path 
          options_file_path = File.expand_path(options_file_path)
          unless File.exists?(options_file_path)
            parser_error "Specified options file '#{options_file_path}' does not exist!"
          end
          # This eval will allow the specified options file to have access to our
          #  scope.  It is important that the variable 'options_file_path' is
          #  accessible, because some existing options files (e.g. puppetdb) rely on
          #  that variable to determine their own location (for use in 'require's, etc.)
          result = result.merge(eval(File.read(options_file_path)))
        end
        result
      end

      def parse_hosts_file(hosts_file_path)
        host_options = Beaker::Options::OptionsHash.new
        host_options = host_options.merge((YAML.load_file(hosts_file_path)))

        # Make sure the roles array is present for all hosts
        host_options['HOSTS'].each_key do |host|
          host_options['HOSTS'][host]['roles'] ||= []
        end
        if host_options.has_key?('CONFIG')
          host_options = host_options.merge(host_options.delete('CONFIG'))
        end
        host_options
      end

    end
  end
end
