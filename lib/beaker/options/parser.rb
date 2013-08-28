module Beaker
  module Options
    class Parser
      attr_accessor :options

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

          validate_args
          @options.dump

          @options
        rescue SystemExit
          exit
        rescue Exception => e
          parser_error e
        end

      end

      def check_yaml_file(f, msg = "")
        if not File.file?(f)
          parser_error "#{f} does not exist (#{msg})"
        end
        begin
          YAML.load_file(f)
        rescue Exception => e
          parser_error "#{f} is not a valid YAML file (#{msg})\n\t#{e}"
        end
      end

      #validation done after all option parsing
      def validate_args
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
        check_yaml_file(@options[:hosts_file], "required host/node configuration information")
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
        if host_options.has_key?('CONFIG')
          host_options = host_options.merge(host_options.delete('CONFIG'))
        end
        host_options
      end

    end
  end
end
