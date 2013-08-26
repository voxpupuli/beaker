module Beaker
  module Options
    class Parser
      GITREPO = 'git://github.com/puppetlabs'

      attr_accessor :options

      def repo?
        GITREPO
      end

      def parser_error msg = ""
        puts "Error in Beaker configuration: " + msg.to_s
        puts "\nUse beaker --help"
        exit
      end

      def initialize
         @command_line_parser = Beaker::Options::CommandLineParser.new
      end

      def parse_args
        #NOTE on argument precedence:
        #
        # Will use env, then hosts/config file, then command line, then file options
        # 
        #NOTE on merging two hashes
        #    $ a = {1=>nil, 2=>'two'}
        #     => {1=>nil, 2=>"two"} 
        #    $ b = {1=>'one', 3=>'three'}
        #     => {1=>"one", 3=>"three"} 
        #    $ a.merge(b)
        #     => {1=>"one", 2=>"two", 3=>"three"} 
        #    $ b.merge(a)
        #     => {1=>nil, 3=>"three", 2=>"two"} 
        # a.merge(b) means combine a & b, and prefer contents of b in case of collisions
        env_vars = Beaker::Options::Defaults.env_vars
        defaults = Beaker::Options::Defaults.defaults
        ssh_defaults = Beaker::Options::Defaults.ssh_defaults

        begin

          # merge the defaults and ssh_defaults
          #  overwrite the defaults with the ssh_defaults
          @options = defaults.merge(ssh_defaults)
          cmd_line_options = @command_line_parser.parse
          file_options = parse_options_file(@options[:options_file])
          # merge together command line and file_options
          #   overwrite file options with command line options
          cmd_line_and_file_options = file_options.merge(cmd_line_options)
          # merge command line and file options with defaults
          #   overwrite defaults with command line and file options 
          @options = @options.merge(cmd_line_and_file_options)

          # merge in env vars
          #   overwrite options (default, file options and command line) with env options
          @options = @options.merge(env_vars)

          #read the hosts file that contains the node configuration and hypervisor info
          
          pre_validate_args

          hosts_options = parse_hosts_file(@options[:hosts_file])
          # merge in host file vars
          #   overwrite options (default, file options, command line, env) with host file options
          @options = @options.merge(hosts_options)
          # re-merge env vars, in case any were overwritten in the hosts file
          #   overwrite options (default, file options, command line, env, hosts file) with env
          @options = @options.merge(env_vars)

          if @options.is_pe?
            @options['pe_ver']           = Beaker::Options::PEVersionScraper.load_pe_version(@options[:pe_dir], @options[:version_file])
            @options['pe_ver_win']       = Beaker::Options::PEVersionScraper.load_pe_version_win(@options[:pe_dir], @options[:version_file])
          else
            @options['puppet_ver']       = @options[:puppet]
            @options['facter_ver']       = @options[:facter]
            @options['hiera_ver']        = @options[:hiera]
            @options['hiera_puppet_ver'] = @options[:hiera_puppet]
          end

          dump_args

          validate_args
          @options
        rescue SystemExit
          exit
        rescue Exception => e
          parser_error e
        end

      end

      def dump_hash(h, separator = '\t\t')
        h.each do |k, v|
          print "#{separator}#{k.to_s} => "
          if v.kind_of?(Hash)
            puts
            dump_hash(v, separator + separator)
          else
            puts "#{v.to_s}"
          end
        end
      end

      def dump_args
        puts "Options:"
        @options.each do |opt, val|
          if val and val != []
            puts "\t#{opt.to_s}:"
            if val.kind_of?(Array)
              val.each do |v|
                puts "\t\t#{v.to_s}"
              end
            elsif val.kind_of?(Hash)
              dump_hash(val, "\t\t")
            else
              puts "\t\t#{val.to_s}"
            end
          end
        end
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
                raise ArgumentError, "Empty directory used as an option (#{root})!"
              end
              files += discover_files
            end
          end
        end
        files
      end

      #validation done after all option parsing
      def validate_args
        if @options[:type] !~ /(pe)|(git)/
          parser_error "--type must be one of pe or git, not '#{@options[:type]}'"
        end

        if not ["fast", "stop", nil].include?(@options[:fail_mode])
          parser_error "--fail-mode must be one of fast, stop" 
        end

      end

      #validation done before parsing host file options
      def pre_validate_args
        if not File.file?(@options[:hosts_file])
          raise "--hosts-file/-h must provide a link to a valid host configuration file"
        end
        begin
          YAML.load_file(@options[:hosts_file])
        rescue Exception => e
          raise "--hosts-file/-h file is not valid YAML\n\t#{e}"
        end
      end

      def parse_options_file(options_file_path)
        result = Beaker::Options::OptionsHash.new
        if options_file_path 
          options_file_path = File.expand_path(options_file_path)
          unless File.exists?(options_file_path)
            raise ArgumentError, "Specified options file '#{options_file_path}' does not exist!"
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
        if host_options['CONFIG']
          host_options = host_options.merge(host_options.delete('CONFIG'))
        end
        host_options
      end

    end
  end
end
