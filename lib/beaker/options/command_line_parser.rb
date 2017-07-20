module Beaker
  module Options
    #An object that parses arguments in the format ['--option', 'value', '--option2', 'value2', '--switch']
    class CommandLineParser

      # @example Create a CommanLineParser
      #   a = CommandLineParser.new
      #
      # @note All of Beaker's supported command line options are defined here
      def initialize
        @cmd_options = Beaker::Options::OptionsHash.new

        @optparse = OptionParser.new do|opts|
          # Set a banner
          opts.banner = "Usage: #{File.basename($0)} [options...]"

          opts.on '-h', '--hosts FILE',
                  'Use host configuration FILE',
                  'Possible FILE values:',
                  'a file path (beaker will parse file directly)',
                  'a beaker-hostgenerator string (BHG generates hosts file)',
                  'omitted (coordinator-only run; no SUTs provisioned)' do |file|
            @cmd_options[:hosts_file] = file
          end

          opts.on '-o', '--options-file FILE',
                  'Read options from FILE',
                  'This should evaluate to a ruby hash.',
                  'CLI optons are given precedence.' do |file|
            @cmd_options[:options_file] =  file
          end

          opts.on '--helper PATH/TO/SCRIPT',
                  'Ruby file evaluated prior to tests',
                  '(a la spec_helper)' do |script|
            @cmd_options[:helper] = script
          end

          opts.on  '--load-path /PATH/TO/DIR,/ADDITIONAL/DIR/PATHS',
                   'Add paths to LOAD_PATH'  do |value|
            @cmd_options[:load_path] = value
          end

          opts.on  '-t', '--tests /PATH/TO/DIR,/ADDITIONA/DIR/PATHS,/PATH/TO/FILE.rb',
                   'Execute tests from paths and files' do |value|
            @cmd_options[:tests] = value
          end

          opts.on '--pre-suite /PRE-SUITE/DIR/PATH,/ADDITIONAL/DIR/PATHS,/PATH/TO/FILE.rb',
                  'Path to project specific steps to be run BEFORE testing' do |value|
            @cmd_options[:pre_suite] = value
          end

          opts.on '--post-suite /POST-SUITE/DIR/PATH,/OPTIONAL/ADDITONAL/DIR/PATHS,/PATH/TO/FILE.rb',
                  'Path to project specific steps to be run AFTER testing' do |value|
            @cmd_options[:post_suite] = value
          end

          opts.on '--pre-cleanup /PRE-CLEANUP/DIR/PATH,/OPTIONAL/ADDITONAL/DIR/PATHS,/PATH/TO/FILE.rb',
                  'Path to project specific steps to be run before cleaning up VMs (will always run)' do |value|
            @cmd_options[:pre_cleanup] = value
          end

          opts.on '--[no-]provision',
                  'Do not provision vm images before testing',
                  '(default: true)' do |bool|
            @cmd_options[:provision] = bool
            unless bool
              @cmd_options[:validate]  = false
              @cmd_options[:configure] = false
            end
          end

          opts.on '--[no-]configure',
                  'Do not configure vm images before testing',
                  '(default: true)' do |bool|
            @cmd_options[:configure] = bool
          end

          opts.on '--preserve-hosts [MODE]',
                  'How should SUTs be treated post test',
                  'Possible values:',
                  'always (keep SUTs alive)',
                  'onfail (keep SUTs alive if failures occur during testing)',
                  'onpass (keep SUTs alive if no failures occur during testing)',
                  'never (cleanup SUTs - shutdown and destroy any changes made during testing)',
                  '(default: never)'  do |mode|
            @cmd_options[:preserve_hosts] = mode || 'always'
          end

          opts.on '--debug-errors',
                  'Enter a pry console if or when a test fails',
                  '(default: false)' do |bool|
            @cmd_options[:debug_errors] = bool
          end

          opts.on '--root-keys',
                  'Install puppetlabs pubkeys for superuser',
                  '(default: false)' do |bool|
            @cmd_options[:root_keys] = bool
          end

          opts.on '--keyfile /PATH/TO/SSH/KEY',
                  'Specify alternate SSH key',
                  '(default: ~/.ssh/id_rsa)' do |key|
            @cmd_options[:keyfile] = key
          end

          opts.on '--timeout TIMEOUT',
                  '(vCloud only) Specify a provisioning timeout (in seconds)',
                  '(default: 300)' do |value|
            @cmd_options[:timeout] = value
          end

          opts.on '-i URI', '--install URI',
                  'Install a project repo/app on the SUTs',
                  'Provide full git URI or use short form KEYWORD/name',
                  'supported keywords: PUPPET, FACTER, HIERA, HIERA-PUPPET' do |value|
            @cmd_options[:install] = value
          end

          opts.on('-m', '--modules URI', 'Select puppet module git install URI') do |value|
            @cmd_options[:modules] = value
          end

          opts.on '-q', '--[no-]quiet',
                  'Do not log output to STDOUT',
                  '(default: false)' do |bool|
            @cmd_options[:quiet] = bool
          end

          opts.on '--[no-]color',
                  'Do not display color in log output',
                  '(default: true)' do |bool|
            @cmd_options[:color] = bool
          end

          opts.on '--[no-]color-host-output',
                  'Ensure SUT colored output is preserved',
                  '(default: false)' do |bool|
            @cmd_options[:color_host_output] = bool
            if bool
              @cmd_options[:color_host_output] = true
            end
          end

          opts.on '--log-level LEVEL',
                  'Log level',
                  'Supported LEVEL keywords:',
                  'trace   : all messages, full stack trace of errors, file copy details',
                  'debug   : all messages, plus full stack trace of errors',
                  'verbose : all messages',
                  'info    : info messages, notifications and warnings',
                  'notify  : notifications and warnings',
                  'warn    : warnings only',
                  '(default: info)' do |val|
            @cmd_options[:log_level] = val
          end

          opts.on '--log-prefix PREFIX',
                  'Use a custom prefix for your Beaker log files',
                  'can provide nested directories (ie. face/man)',
                  '(defaults to hostfile name. ie. ../i/07.yml --> "07")' do |val|
            @cmd_options[:log_prefix] = val
          end

          opts.on  '-d', '--[no-]dry-run',
                   'Report what would happen on targets',
                   '(default: false)' do |bool|
            @cmd_options[:dry_run] = bool
          end

          opts.on '--fail-mode [MODE]',
                  'How should the harness react to errors/failures',
                  'Possible values:',
                  'fast (skip all subsequent tests)',
                  'slow (attempt to continue run post test failure)',
                  'stop (DEPRECATED, please use fast)',
                  '(default: slow)'  do |mode|
            @cmd_options[:fail_mode] = mode =~ /stop/ ? 'fast' :  mode
          end

          opts.on '--[no-]ntp',
                  'Sync time on SUTs before testing',
                  '(default: false)' do |bool|
            @cmd_options[:timesync] = bool
          end

          opts.on '--repo-proxy',
                  'Proxy packaging repositories on ubuntu, debian, cumulus and solaris-11',
                  '(default: false)' do
            @cmd_options[:repo_proxy] = true
          end

          opts.on '--add-el-extras',
                  'Add Extra Packages for Enterprise Linux (EPEL) repository to el-* hosts',
                  '(default: false)' do
            @cmd_options[:add_el_extras] = true
          end

          opts.on '--package-proxy URL', 'Set proxy url for package managers (yum and apt)' do |value|
            @cmd_options[:package_proxy] = value
          end

          opts.on '--[no-]validate',
                  'Validate that SUTs are correctly provisioned before running tests',
                  '(default: true)' do |bool|
            @cmd_options[:validate] = bool
          end

          opts.on '--collect-perf-data [MODE]',
                  'Collect SUT performance and load data',
                  'Possible values:',
                  'aggressive (poll every minute)',
                  'normal (poll every 10 minutes)',
                  'none (do not collect perf data)',
                  '(default: normal)' do |mode|
            @cmd_options[:collect_perf_data] = mode || 'normal'
          end

          opts.on('--version', 'Report currently running version of beaker' ) do
            @cmd_options[:beaker_version_print] = true
          end

          opts.on('--parse-only', 'Display beaker parsed options and exit' ) do
            @cmd_options[:parse_only] = true
          end

          opts.on('--help', 'Display this screen' ) do
            @cmd_options[:help] = true
          end

          opts.on '-c', '--config FILE',
                  'DEPRECATED, use --hosts' do |file|
            @cmd_options[:hosts_file] = file
          end

          opts.on '--[no-]debug',
                  'DEPRECATED, use --log-level' do |bool|
            @cmd_options[:log_level] =  bool ? 'debug' : 'info'
          end

          opts.on '-x', '--[no-]xml',
                  'DEPRECATED - JUnit XML now generated by default' do
            #noop
          end

          opts.on '--type TYPE',
                  'DEPRECATED - pe/foss/aio determined during runtime' do |type|
            #backwards compatability, oh how i hate you
            @cmd_options[:type] = type
          end

          opts.on '--tag TAGS',
                  'DEPRECATED - use --test-tag-and instead' do |value|
            @cmd_options[:test_tag_and] = value
          end
          opts.on '--test-tag-and TAGS',
                  'Run the set of tests matching ALL of the provided single or comma separated list of tags' do |value|
            @cmd_options[:test_tag_and] = value
          end

          opts.on '--test-tag-or TAGS',
                  'Run the set of tests matching ANY of the provided single or comma separated list of tags' do |value|
            @cmd_options[:test_tag_or] = value
          end

          opts.on '--exclude-tag TAGS',
                  'DEPRECATED - use --test-tag-exclude instead' do |value|
            @cmd_options[:test_tag_exclude] = value
          end
          opts.on '--test-tag-exclude TAGS',
                  'Run the set of tests that do not contain ANY of the provided single or comma separated list of tags' do |value|
            @cmd_options[:test_tag_exclude] = value
          end

          opts.on '--xml-time-order',
                  'Output an additional JUnit XML file, sorted by execution time' do |bool|
            @cmd_options[:xml_time_enabled] = bool
          end

        end

      end

      # Parse an array of arguments into a Hash of options
      # @param [Array] args The array of arguments to consume
      #
      # @example
      #   args = ['--option', 'value', '--option2', 'value2', '--switch']
      #   parser = CommandLineParser.new
      #   parser.parse(args) == {:option => 'value, :options2 => value, :switch => true}
      #
      # @return [Hash] Return the Hash of options
      def parse( args = ARGV )
        @optparse.parse(args)
        @cmd_options
      end

      # Generate a string representing the supported arguments
      #
      # @example
      #    parser = CommandLineParser.new
      #    parser.usage = "Options:  ..."
      #
      # @return [String] Return a string representing the available arguments
      def usage
        @optparse.help
      end
    end
  end
end
