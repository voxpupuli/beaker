module PuppetAcceptance
  class Options
    GITREPO = 'git://github.com/puppetlabs'

    def self.options
      return @options
    end

    def self.repo?
      GITREPO
    end

    def self.parse_install_options(install_opts)
      install_opts.map! { |opt|
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
      install_opts
    end

    def self.file_list(paths)
      files = []
      if not paths.empty? 
        paths.each do |root|
          if File.file? root then
            files << root
          else
            files += Dir.glob(
              File.join(root, "**/*.rb")
            ).select { |f| File.file?(f) }
          end
        end
      end
      files
    end

    def self.parse_args
      return @options if @options

      @no_args = ARGV.empty? ? true : false

      @defaults = {}
      @options = {}
      @options_from_file = {}

      optparse = OptionParser.new do|opts|
        # Set a banner
        opts.banner = "Usage: #{File.basename($0)} [options...]"

        @defaults[:config] = nil
        opts.on '-c', '--config FILE',
                'Use configuration FILE' do |file|
          @options[:config] = file
        end

        @defaults[:options_file] = nil
        opts.on '-o', '--options-file FILE',
                'Read options from FILE',
                'This should evaluate to a ruby hash.',
                'CLI optons are given precedence.' do |file|
          @options_from_file = parse_options_file file
        end

        @defaults[:type] = 'pe'
        opts.on '--type TYPE',
                'one of git or pe', 
                'used to determine underlying path structure of puppet install',
                'defaults to pe' do |type|
          @options[:type] = type
        end

        @defaults[:helper] = []
        opts.on '--helper PATH/TO/SCRIPT',
                'Ruby file evaluated prior to tests',
                '(a la spec_helper)' do |script|
          @options[:helper] = []
          if script.is_a?(Array)
            @options[:helper] += script
          elsif script =~ /,/
            @options[:helper] += script.split(',')
          else
            @options[:helper] << script
          end
        end

        @defaults[:load_path] = []
        opts.on  '--load-path /PATH/TO/DIR,/ADDITIONAL/DIR/PATHS',
                 'Add paths to LOAD_PATH'  do |value|
          @options[:load_path] = []
          if value.is_a?(Array)
            @options[:load_path] += value
          elsif value =~ /,/
            @options[:load_path] += value.split(',')
          else
            @options[:load_path] << value
          end
        end

        @defaults[:tests] = []
        opts.on  '-t', '--tests /PATH/TO/DIR,/ADDITIONA/DIR/PATHS,/PATH/TO/FILE.rb',
                 'Execute tests from paths and files' do |value|
          @options[:tests] = []
          if value.is_a?(Array)
            @options[:tests] += value
          elsif value =~ /,/
            @options[:tests] += value.split(',')
          else
            @options[:tests] << value
          end
          @options[:tests] = file_list(@options[:tests])
          if @options[:tests].empty?
            raise ArgumentError, "No tests to run!"
          end
        end

        @defaults[:pre_suite] = []
        opts.on '--pre-suite /PRE-SUITE/DIR/PATH,/ADDITIONAL/DIR/PATHS,/PATH/TO/FILE.rb',
                'Path to project specific steps to be run BEFORE testing' do |value|
          @options[:pre_suite] = []
          if value.is_a?(Array)
            @options[:pre_suite] += value
          elsif value =~ /,/
            @options[:pre_suite] += value.split(',')
          else
            @options[:pre_suite] << value
          end
          @options[:pre_suite] = file_list(@options[:pre_suite])
          if @options[:pre_suite].empty?
            raise ArgumentError, "Empty pre-suite!"
          end
        end

        @defaults[:post_suite] = []
        opts.on '--post-suite /POST-SUITE/DIR/PATH,/OPTIONAL/ADDITONAL/DIR/PATHS,/PATH/TO/FILE.rb',
                'Path to project specific steps to be run AFTER testing' do |value|
          @options[:post_suite] = []
          if value.is_a?(Array)
            @options[:post_suite] += value
          elsif value =~ /,/
            @options[:post_suite] += value.split(',')
          else
            @options[:post_suite] << value
          end
          @options[:post_suite] = file_list(@options[:post_suite])
          if @options[:post_suite].empty?
            raise ArgumentError, "Empty post-suite!"
          end
        end

        @defaults[:provision] = true
        opts.on '--[no-]provision',
                'Do not provision vm images before testing',
                '(default: true)' do |bool|
          @options[:provision] = bool
        end

        @defaults[:preserve_hosts] = false
        opts.on '--[no-]preserve-hosts',
                'Preserve cloud instances' do |value|
          @options[:preserve_hosts] = value
        end

        @defaults[:root_keys] = false
        opts.on '--root-keys',
                'Install puppetlabs pubkeys for superuser',
                '(default: false)' do |bool|
          @options[:root_keys] = bool
        end

        @defaults[:keyfile] = "#{ENV['HOME']}/.ssh/id_rsa"
        opts.on '--keyfile /PATH/TO/SSH/KEY',
                'Specify alternate SSH key',
                '(default: ~/.ssh/id_rsa)' do |key|
          @options[:keyfile] = key
        end


        @defaults[:install] = []
        opts.on '-i URI', '--install URI',
                'Install a project repo/app on the SUTs', 
                'Provide full git URI or use short form KEYWORD/name',
                'supported keywords: PUPPET, FACTER, HIERA, HIERA-PUPPET' do |value|
          @options[:install] = []
          if value.is_a?(Array)
            @options[:install] += value
          elsif value =~ /,/
            @options[:install] += value.split(',')
          else
            @options[:install] << value
          end
          @options[:install] = parse_install_options(@options[:install])
        end

        @defaults[:modules] = []
        opts.on('-m', '--modules URI', 'Select puppet module git install URI') do |value|
          @options[:modules] ||= []
          @options[:modules] << value
        end

        @defaults[:quiet] = false
        opts.on '-q', '--[no-]quiet',
                'Do not log output to STDOUT',
                '(default: false)' do |bool|
          @options[:quiet] = bool
        end

        @defaults[:xml] = false
        opts.on '-x', '--[no-]xml',
                'Emit JUnit XML reports on tests',
                '(default: false)' do |bool|
          @options[:xml] = bool
        end

        @defaults[:color] = true
        opts.on '--[no-]color',
                'Do not display color in log output',
                '(default: true)' do |bool|
          @options[:color] = bool
        end

        @defaults[:debug] = false
        opts.on '--[no-]debug',
                'Enable full debugging',
                '(default: false)' do |bool|
          @options[:debug] = bool
        end

        @defaults[:dry_run] = false
        opts.on  '-d', '--[no-]dry-run',
                 'Report what would happen on targets',
                 '(default: false)' do |bool|
          @options[:dry_run] = bool
          $dry_run = bool
        end

        @defaults[:fail_mode] = nil
        opts.on '--fail-mode [MODE]',
                'How should the harness react to errors/failures',
                'Possible values:',
                'fast (skip all subsequent tests, cleanup, exit)',
                'stop (skip all subsequent tests, do no cleanup, exit immediately)'  do |mode|
          @options[:fail_mode] = mode
        end

        @defaults[:timesync] = false
        opts.on '--[no-]ntp',
                'Sync time on SUTs before testing',
                '(default: false)' do |bool|
          @options[:timesync] = bool
        end

        @defaults[:repo_proxy] = false
        opts.on '--repo-proxy',
                'Proxy packaging repositories on ubuntu, debian and solaris-11',
                '(default: false)' do
          @options[:repo_proxy] = true
        end

        @defaults[:add_el_extras] = false
        opts.on '--add-el-extras',
                'Add Extra Packages for Enterprise Linux (EPEL) repository to el-* hosts',
                '(default: false)' do
          @options[:add_el_extras] = true
        end

        opts.on('--help', 'Display this screen' ) do |yes|
          puts opts
          exit
        end
      end

      optparse.parse!

      # We have use the @no_args var because OptParse consumes ARGV as it parses
      # so we have to check the value of ARGV at the begining of the method,
      # let the options be set, then output usage.
      puts optparse if @no_args

      # merge in the options that we read from the file
      @options = @options_from_file.merge(@options)
      # merge in defaults
      @options = @defaults.merge(@options)

      if @options[:type] !~ /(pe)|(git)/
        raise ArgumentError.new("--type must be one of pe or git, not '#{@options[:type]}'")
      end

      raise ArgumentError.new("--fail-mode must be one of fast, stop") unless ["fast", "stop", nil].include?(@options[:fail_mode])

      @options
    end

    def self.parse_options_file(options_file_path)
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

      result
    end
  end
end
