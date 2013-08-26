module Beaker
  module Options
    class CommandLineParser
      def initialize
        @cmd_options = Beaker::Options::OptionsHash.new

        @optparse = OptionParser.new do|opts|
          # Set a banner
          opts.banner = "Usage: #{File.basename($0)} [options...]"

          opts.on '-h', '--hosts FILE',
                  'Use host configuration FILE',
                  '(default sample.cfg)'  do |file|
            @cmd_options[:hosts_file] = file
          end

          opts.on '-o', '--options-file FILE',
                  'Read options from FILE',
                  'This should evaluate to a ruby hash.',
                  'CLI optons are given precedence.' do |file|
            @cmd_options[:options_file] =  file
          end

          opts.on '--type TYPE',
                  'one of git or pe', 
                  'used to determine underlying path structure of puppet install',
                  '(default pe)' do |type|
            @cmd_options[:type] = type
          end

          opts.on '--helper PATH/TO/SCRIPT',
                  'Ruby file evaluated prior to tests',
                  '(a la spec_helper)' do |script|
            @cmd_options[:helper] = []
            if script.is_a?(Array)
              @cmd_options[:helper] += script
            elsif script =~ /,/
              @cmd_options[:helper] += script.split(',')
            else
              @cmd_options[:helper] << script
            end
          end

          opts.on  '--load-path /PATH/TO/DIR,/ADDITIONAL/DIR/PATHS',
                   'Add paths to LOAD_PATH'  do |value|
            @cmd_options[:load_path] = []
            if value.is_a?(Array)
              @cmd_options[:load_path] += value
            elsif value =~ /,/
              @cmd_options[:load_path] += value.split(',')
            else
              @cmd_options[:load_path] << value
            end
          end

          opts.on  '-t', '--tests /PATH/TO/DIR,/ADDITIONA/DIR/PATHS,/PATH/TO/FILE.rb',
                   'Execute tests from paths and files' do |value|
            @cmd_options[:tests] = []
            if value.is_a?(Array)
              @cmd_options[:tests] += value
            elsif value =~ /,/
              @cmd_options[:tests] += value.split(',')
            else
              @cmd_options[:tests] << value
            end
            @cmd_options[:tests] = file_list(cmd_options[:tests])
            if @cmd_options[:tests].empty?
              raise ArgumentError, "No tests to run!"
            end
          end

          opts.on '--pre-suite /PRE-SUITE/DIR/PATH,/ADDITIONAL/DIR/PATHS,/PATH/TO/FILE.rb',
                  'Path to project specific steps to be run BEFORE testing' do |value|
            @cmd_options[:pre_suite] = []
            if value.is_a?(Array)
              @cmd_options[:pre_suite] += value
            elsif value =~ /,/
              @cmd_options[:pre_suite] += value.split(',')
            else
              @cmd_options[:pre_suite] << value
            end
            @cmd_options[:pre_suite] = file_list(cmd_options[:pre_suite])
            if @cmd_options[:pre_suite].empty?
              raise ArgumentError, "Empty pre-suite!"
            end
          end

          opts.on '--post-suite /POST-SUITE/DIR/PATH,/OPTIONAL/ADDITONAL/DIR/PATHS,/PATH/TO/FILE.rb',
                  'Path to project specific steps to be run AFTER testing' do |value|
            @cmd_options[:post_suite] = []
            if value.is_a?(Array)
              @cmd_options[:post_suite] += value
            elsif value =~ /,/
              @cmd_options[:post_suite] += value.split(',')
            else
              @cmd_options[:post_suite] << value
            end
            @cmd_options[:post_suite] = file_list(cmd_options[:post_suite])
            if @cmd_options[:post_suite].empty?
              raise ArgumentError, "Empty post-suite!"
            end
          end

          opts.on '--[no-]provision',
                  'Do not provision vm images before testing',
                  '(default: true)' do |bool|
            @cmd_options[:provision] = bool
          end

          opts.on '--[no-]preserve-hosts',
                  'Preserve cloud instances' do |value|
            @cmd_options[:preserve_hosts] = value
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


          opts.on '-i URI', '--install URI',
                  'Install a project repo/app on the SUTs', 
                  'Provide full git URI or use short form KEYWORD/name',
                  'supported keywords: PUPPET, FACTER, HIERA, HIERA-PUPPET' do |value|
            @cmd_options[:install] = []
            if value.is_a?(Array)
              @cmd_options[:install] += value
            elsif value =~ /,/
              @cmd_options[:install] += value.split(',')
            else
              @cmd_options[:install] << value
            end
            @cmd_options[:install] = parse_git_repos(cmd_options[:install])
          end

          opts.on('-m', '--modules URI', 'Select puppet module git install URI') do |value|
            @cmd_options[:modules] ||= []
            @cmd_options[:modules] << value
          end

          opts.on '-q', '--[no-]quiet',
                  'Do not log output to STDOUT',
                  '(default: false)' do |bool|
            @cmd_options[:quiet] = bool
          end

          opts.on '-x', '--[no-]xml',
                  'Emit JUnit XML reports on tests',
                  '(default: false)' do |bool|
            @cmd_options[:xml] = bool
          end

          opts.on '--[no-]color',
                  'Do not display color in log output',
                  '(default: true)' do |bool|
            @cmd_options[:color] = bool
          end

          opts.on '--[no-]debug',
                  'Enable full debugging',
                  '(default: false)' do |bool|
            @cmd_options[:debug] = bool
          end

          opts.on  '-d', '--[no-]dry-run',
                   'Report what would happen on targets',
                   '(default: false)' do |bool|
            @cmd_options[:dry_run] = bool
            $dry_run = bool
          end

          opts.on '--fail-mode [MODE]',
                  'How should the harness react to errors/failures',
                  'Possible values:',
                  'fast (skip all subsequent tests, cleanup, exit)',
                  'stop (skip all subsequent tests, do no cleanup, exit immediately)'  do |mode|
            @cmd_options[:fail_mode] = mode
          end

          opts.on '--[no-]ntp',
                  'Sync time on SUTs before testing',
                  '(default: false)' do |bool|
            @cmd_options[:timesync] = bool
          end

          opts.on '--repo-proxy',
                  'Proxy packaging repositories on ubuntu, debian and solaris-11',
                  '(default: false)' do
            @cmd_options[:repo_proxy] = true
          end

          opts.on '--add-el-extras',
                  'Add Extra Packages for Enterprise Linux (EPEL) repository to el-* hosts',
                  '(default: false)' do
            @cmd_options[:add_el_extras] = true
          end

          opts.on '-c', '--config FILE',
                  'DEPRECATED use --hosts' do |file|
            @cmd_options[:hosts_file] = file
          end

          opts.on('--help', 'Display this screen' ) do |yes|
            puts opts
            exit
          end
        end

      end

      def parse
        @optparse.parse!
        @cmd_options
      end

      def usage
        @optparse.help
      end

    end
  end
end
