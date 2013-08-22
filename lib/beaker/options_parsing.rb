module Beaker
  class Options
    GITREPO = 'git://github.com/puppetlabs'

    attr_accessor :options

    def repo?
      GITREPO
    end

    def env_vars
      {
        :keyfile => "#{ENV['HOME']}/.ssh/id_rsa",
        :keys => ["#{ENV['HOME']}/.ssh/id_rsa"],
        :user_known_hosts_file => "#{ENV['HOME']}/.ssh/known_hosts",
        :consoleport => ENV['consoleport'] ? ENV['consoleport'].to_i : nil, 
        :type => ENV['IS_PE'] ? 'pe' : nil,
        :pe_dir => ENV['pe_dist_dir'],
        :pe_version_file => ENV['pe_version_file'],
        :pe_version_file_win => ENV['pe_version_file'], 
      }.delete_if {|key, value| value.nil? or value.empty? }
    end

    def defaults
      {
        :hosts_file => 'sample.cfg',
        :options_file => nil,
        :type => 'pe',
        :helper => [],
        :load_path => [],
        :tests => [],
        :pre_suite => [],
        :post_suite => [],
        :provision => true,
        :preserve_hosts => false,
        :root_keys => false,
        :install => [],
        :modules => [],
        :quiet => false,
        :xml => false,
        :color => true,
        :debug => false,
        :dry_run => false,
        :fail_mode => nil,
        :timesync => false,
        :repo_proxy => false,
        :add_el_extras => false,
        :consoleport => 443,
        :pe_dir => '/opt/enterprise/dists',
        :pe_version_file => 'LATEST',
        :pe_version_file_win => 'LATEST-win',
      }
    end

    def ssh_defaults
      {
        :config                => false,
        :paranoid              => false,
        :timeout               => 300,
        :auth_methods          => ["publickey"],
        :port                  => 22,
        :forward_agent         => true
      }
    end

    def initialize
      @options = {}
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

      # merge the defaults and ssh_defaults
      #  overwrite the defaults with the ssh_defaults
      @options = defaults.merge(ssh_defaults)

      cmd_line_options = parse_argv
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
      hosts_options = parse_hosts_file(@options[:hosts_file])
      # merge in host file vars
      #   overwrite options (default, file options, command line, env) with host file options
      @options = @options.merge(hosts_options)
      # re-merge env vars, in case any were overwritten in the hosts file
      #   overwrite options (default, file options, command line, env, hosts file) with env
      @options = @options.merge(env_vars)

      if is_pe?
        @options['pe_ver']           = puppet_enterprise_version
        @options['pe_ver_win']       = puppet_enterprise_version_win
      else
        @options['puppet_ver']       = @options[:puppet]
        @options['facter_ver']       = @options[:facter]
        @options['hiera_ver']        = @options[:hiera]
        @options['hiera_puppet_ver'] = @options[:hiera_puppet]
      end

      dump_args

      validate_args
      @options

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

    def validate_args
      if @options[:type] !~ /(pe)|(git)/
        raise ArgumentError.new("--type must be one of pe or git, not '#{@options[:type]}'")
      end

      raise ArgumentError.new("--fail-mode must be one of fast, stop") unless ["fast", "stop", nil].include?(@options[:fail_mode])

    end

    def parse_argv
      cmd_options = {}

      optparse = OptionParser.new do|opts|
        # Set a banner
        opts.banner = "Usage: #{File.basename($0)} [options...]"

        opts.on '-h', '--hosts FILE',
                'Use host configuration FILE',
                '(default sample.cfg)'  do |file|
          cmd_options[:hosts_file] = file
        end

        opts.on '-o', '--options-file FILE',
                'Read options from FILE',
                'This should evaluate to a ruby hash.',
                'CLI optons are given precedence.' do |file|
          cmd_options[:options_file] =  file
        end

        opts.on '--type TYPE',
                'one of git or pe', 
                'used to determine underlying path structure of puppet install',
                '(default pe)' do |type|
          cmd_options[:type] = type
        end

        opts.on '--helper PATH/TO/SCRIPT',
                'Ruby file evaluated prior to tests',
                '(a la spec_helper)' do |script|
          cmd_options[:helper] = []
          if script.is_a?(Array)
            cmd_options[:helper] += script
          elsif script =~ /,/
            cmd_options[:helper] += script.split(',')
          else
            cmd_options[:helper] << script
          end
        end

        opts.on  '--load-path /PATH/TO/DIR,/ADDITIONAL/DIR/PATHS',
                 'Add paths to LOAD_PATH'  do |value|
          cmd_options[:load_path] = []
          if value.is_a?(Array)
            cmd_options[:load_path] += value
          elsif value =~ /,/
            cmd_options[:load_path] += value.split(',')
          else
            cmd_options[:load_path] << value
          end
        end

        opts.on  '-t', '--tests /PATH/TO/DIR,/ADDITIONA/DIR/PATHS,/PATH/TO/FILE.rb',
                 'Execute tests from paths and files' do |value|
          cmd_options[:tests] = []
          if value.is_a?(Array)
            cmd_options[:tests] += value
          elsif value =~ /,/
            cmd_options[:tests] += value.split(',')
          else
            cmd_options[:tests] << value
          end
          cmd_options[:tests] = file_list(cmd_options[:tests])
          if cmd_options[:tests].empty?
            raise ArgumentError, "No tests to run!"
          end
        end

        opts.on '--pre-suite /PRE-SUITE/DIR/PATH,/ADDITIONAL/DIR/PATHS,/PATH/TO/FILE.rb',
                'Path to project specific steps to be run BEFORE testing' do |value|
          cmd_options[:pre_suite] = []
          if value.is_a?(Array)
            cmd_options[:pre_suite] += value
          elsif value =~ /,/
            cmd_options[:pre_suite] += value.split(',')
          else
            cmd_options[:pre_suite] << value
          end
          cmd_options[:pre_suite] = file_list(cmd_options[:pre_suite])
          if cmd_options[:pre_suite].empty?
            raise ArgumentError, "Empty pre-suite!"
          end
        end

        opts.on '--post-suite /POST-SUITE/DIR/PATH,/OPTIONAL/ADDITONAL/DIR/PATHS,/PATH/TO/FILE.rb',
                'Path to project specific steps to be run AFTER testing' do |value|
          cmd_options[:post_suite] = []
          if value.is_a?(Array)
            cmd_options[:post_suite] += value
          elsif value =~ /,/
            cmd_options[:post_suite] += value.split(',')
          else
            cmd_options[:post_suite] << value
          end
          cmd_options[:post_suite] = file_list(cmd_options[:post_suite])
          if cmd_options[:post_suite].empty?
            raise ArgumentError, "Empty post-suite!"
          end
        end

        opts.on '--[no-]provision',
                'Do not provision vm images before testing',
                '(default: true)' do |bool|
          cmd_options[:provision] = bool
        end

        opts.on '--[no-]preserve-hosts',
                'Preserve cloud instances' do |value|
          cmd_options[:preserve_hosts] = value
        end

        opts.on '--root-keys',
                'Install puppetlabs pubkeys for superuser',
                '(default: false)' do |bool|
          cmd_options[:root_keys] = bool
        end

        opts.on '--keyfile /PATH/TO/SSH/KEY',
                'Specify alternate SSH key',
                '(default: ~/.ssh/id_rsa)' do |key|
          cmd_options[:keyfile] = key
        end


        opts.on '-i URI', '--install URI',
                'Install a project repo/app on the SUTs', 
                'Provide full git URI or use short form KEYWORD/name',
                'supported keywords: PUPPET, FACTER, HIERA, HIERA-PUPPET' do |value|
          cmd_options[:install] = []
          if value.is_a?(Array)
            cmd_options[:install] += value
          elsif value =~ /,/
            cmd_options[:install] += value.split(',')
          else
            cmd_options[:install] << value
          end
          cmd_options[:install] = parse_git_repos(cmd_options[:install])
        end

        opts.on('-m', '--modules URI', 'Select puppet module git install URI') do |value|
          cmd_options[:modules] ||= []
          cmd_options[:modules] << value
        end

        opts.on '-q', '--[no-]quiet',
                'Do not log output to STDOUT',
                '(default: false)' do |bool|
          cmd_options[:quiet] = bool
        end

        opts.on '-x', '--[no-]xml',
                'Emit JUnit XML reports on tests',
                '(default: false)' do |bool|
          cmd_options[:xml] = bool
        end

        opts.on '--[no-]color',
                'Do not display color in log output',
                '(default: true)' do |bool|
          cmd_options[:color] = bool
        end

        opts.on '--[no-]debug',
                'Enable full debugging',
                '(default: false)' do |bool|
          cmd_options[:debug] = bool
        end

        opts.on  '-d', '--[no-]dry-run',
                 'Report what would happen on targets',
                 '(default: false)' do |bool|
          cmd_options[:dry_run] = bool
          $dry_run = bool
        end

        opts.on '--fail-mode [MODE]',
                'How should the harness react to errors/failures',
                'Possible values:',
                'fast (skip all subsequent tests, cleanup, exit)',
                'stop (skip all subsequent tests, do no cleanup, exit immediately)'  do |mode|
          cmd_options[:fail_mode] = mode
        end

        opts.on '--[no-]ntp',
                'Sync time on SUTs before testing',
                '(default: false)' do |bool|
          cmd_options[:timesync] = bool
        end

        opts.on '--repo-proxy',
                'Proxy packaging repositories on ubuntu, debian and solaris-11',
                '(default: false)' do
          cmd_options[:repo_proxy] = true
        end

        opts.on '--add-el-extras',
                'Add Extra Packages for Enterprise Linux (EPEL) repository to el-* hosts',
                '(default: false)' do
          cmd_options[:add_el_extras] = true
        end

        opts.on '-c', '--config FILE',
                'DEPRECATED use --hosts' do |file|
          cmd_options[:hosts_file] = file
        end

        opts.on('--help', 'Display this screen' ) do |yes|
          puts opts
          exit
        end
      end

      optparse.parse!

      cmd_options
    end

    def parse_options_file(options_file_path)
      result = {}
      if options_file_path 
        options_file_path = File.expand_path(options_file_path)
        unless File.exists?(options_file_path)
          raise ArgumentError, "Specified options file '#{options_file_path}' does not exist!"
        end
        # This eval will allow the specified options file to have access to our
        #  scope.  It is important that the variable 'options_file_path' is
        #  accessible, because some existing options files (e.g. puppetdb) rely on
        #  that variable to determine their own location (for use in 'require's, etc.)
        result = eval(File.read(options_file_path))
        unless result.is_a? Hash
          raise ArgumentError, "Options file '#{options_file_path}' must return a hash!"
        end
      end
      result
    end

    def parse_hosts_file(hosts_file_path)
      host_options = {}
      if hosts_file_path.is_a? Hash
        host_options = hosts_file_path
      else
        host_options = YAML.load_file(hosts_file_path)

        # Make sure the roles array is present for all hosts
        host_options['HOSTS'].each_key do |host|
          host_options['HOSTS'][host]['roles'] ||= []
        end
      end
      if host_options['CONFIG']
        host_options.merge(host_options.delete('CONFIG'))
      end
      host_options
    end

    def is_pe?
      @options[:type] =~ /pe/ ? true : false
    end

    def load_pe_version
      dist_dir = @options[:pe_dir]
      version_file = @options[:version_file]
      version = ""
      begin
        open("#{dist_dir}/#{version_file}") do |file|
          while line = file.gets
            if /(\w.*)/ =~ line then
              version = $1.strip
              puts "Found LATEST: Puppet Enterprise Version #{version}"
            end
          end
        end
      rescue
        version = 'unknown'
      end
      return version
    end

    def puppet_enterprise_version
      load_pe_version if is_pe?
    end

    def load_pe_version_win
      dist_dir = @options[:pe_dir]
      version_file = @options[:version_file]
      version = ""
      begin
        open("#{dist_dir}/#{version_file}") do |file|
          while line = file.gets
            if /(\w.*)/ =~ line then
              version=$1.strip
              puts "Found LATEST: Puppet Enterprise Windows Version #{version}"
            end
          end
        end
      rescue
        version = 'unknown'
      end
      return version
    end

    def puppet_enterprise_version_win
      load_pe_version_win if is_pe?
    end
  end
end
