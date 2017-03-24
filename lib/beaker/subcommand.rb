require "thor"
require "fileutils"
require "beaker/subcommands/subcommand_util"

module Beaker
  class Subcommand < Thor
    SubcommandUtil = Beaker::Subcommands::SubcommandUtil


    def initialize(*args)
      super
      FileUtils.mkdir_p(SubcommandUtil::CONFIG_DIR)
      FileUtils.touch(SubcommandUtil::SUBCOMMAND_OPTIONS) unless SubcommandUtil::SUBCOMMAND_OPTIONS.exist?
      FileUtils.touch(SubcommandUtil::SUBCOMMAND_STATE) unless SubcommandUtil::SUBCOMMAND_STATE.exist?
      @cli = Beaker::CLI.new
    end

    # Options listed in this group 'Beaker run' are options that can be set on subcommands
    # but are not processed by the subcommand itself. They are passed through so that when
    # a Beaker::CLI object executes, it can pick up these options. Notably excluded from this
    # group are `help` and `version`. Please note that whenever the command_line_parser.rb is
    # updated, this list should also be updated as well.
    class_option :hosts, :aliases => '-h', :type => :string, :group => 'Beaker run'
    class_option :'options-file', :aliases => '-o', :type => :string, :group => 'Beaker run'
    class_option :helper, :type => :string, :group => 'Beaker run'
    class_option :'load-path', :type => :string, :group => 'Beaker run'
    class_option :tests, :aliases => '-t', :type => :string, :group => 'Beaker run'
    class_option :'pre-suite', :type => :string, :group => 'Beaker run'
    class_option :'post-suite', :type => :string, :group => 'Beaker run'
    class_option :'pre-cleanup', :type => :string, :group => 'Beaker run'
    class_option :'provision', :type => :boolean, :group => 'Beaker run'
    class_option :'preserve-hosts', :type => :string, :group => 'Beaker run'
    class_option :'root-keys', :type => :boolean, :group => 'Beaker run'
    class_option :keyfile, :type => :string, :group => 'Beaker run'
    class_option :timeout, :type => :string, :group => 'Beaker run'
    class_option :install, :aliases => '-i', :type => :string, :group => 'Beaker run'
    class_option :modules, :aliases => '-m', :type => :string, :group => 'Beaker run'
    class_option :quiet, :aliases => '-q', :type => :boolean, :group => 'Beaker run'
    class_option :color, :type => :boolean, :group => 'Beaker run'
    class_option :'color-host-output', :type => :boolean, :group => 'Beaker run'
    class_option :'log-level', :type => :string, :group => 'Beaker run'
    class_option :'log-prefix', :type => :string, :group => 'Beaker run'
    class_option :'dry-run', :type => :boolean, :group => 'Beaker run'
    class_option :'fail-mode', :type => :string, :group => 'Beaker run'
    class_option :ntp, :type => :boolean, :group => 'Beaker run'
    class_option :'repo-proxy', :type => :boolean, :group => 'Beaker run'
    class_option :'add-el-extras', :type => :boolean, :group => 'Beaker run'
    class_option :'package-proxy', :type => :string, :group => 'Beaker run'
    class_option :'validate', :type => :boolean, :group => 'Beaker run'
    class_option :'collect-perf-data', :type => :boolean, :group => 'Beaker run'
    class_option :'parse-only', :type => :boolean, :group => 'Beaker run'
    class_option :tag, :type => :string, :group => 'Beaker run'
    class_option :'exclude-tags', :type => :string, :group => 'Beaker run'
    class_option :'xml-time-order', :type => :boolean, :group => 'Beaker run'

    desc "init BEAKER_RUN_OPTIONS", "Initializes the required configuration for Beaker subcommand execution"
    option :help, :type => :boolean, :hide => true
    long_desc <<-LONGDESC
      Initializes the required .beaker configuration folder. This folder contains
      a subcommand_options.yaml file that is user-facing; altering this file will
      alter the options subcommand execution.

      Also modified in this operation is the .subcommand_state file that is used
      by beaker to determine subcommand state. You as a user should never have to
      edit this file.
    LONGDESC
    def init()
      if options[:help]
        invoke :help, [], ["init"]
        return
      end

      @cli.parse_options

      # delete unnecessary keys for saving the options
      options_to_write = @cli.configured_options
      # Remove keys we don't want to save
      [:timestamp, :logger, :command_line, :beaker_version, :hosts_file].each do |key|
        options_to_write.delete(key)
      end

      options_to_write = SubcommandUtil.sanitize_options_for_save(options_to_write)

      @cli.logger.notify 'writing configured options to disk'
      File.open(SubcommandUtil::SUBCOMMAND_OPTIONS, 'w') do |f|
        f.write(options_to_write.to_yaml)
      end

      state = YAML::Store.new(SubcommandUtil::SUBCOMMAND_STATE)
      state.transaction do
        state['provisioned'] = false
      end
    end

    desc "provision", "Provisions the beaker systems under test(SUTs)"
    option :help, :type => :boolean, :hide => true
    long_desc <<-LONGDESC
    Provisions hosts defined in your subcommand_options file. You can pass the --hosts
    flag here to override any hosts provided there. Really, you can pass most any beaker
    flag here to override.
    LONGDESC
    def provision()
      if options[:help]
        invoke :help, [], ["provision"]
        return
      end

      state = YAML::Store.new(SubcommandUtil::SUBCOMMAND_STATE)
      if state.transaction { state['provisioned']}
        SubcommandUtil.error_with('Provisioned SUTs detected. Please destroy and reprovision.')
      end
      @cli.parse_options
      @cli.provision

      # Sanitize the hosts
      cleaned_hosts = SubcommandUtil.sanitize_options_for_save(@cli.combined_instance_and_options_hosts)

      # should we only update the options here with the new host? Or update the settings
      # with whatever new flags may have been provided with provision?
      options_storage = YAML::Store.new(SubcommandUtil::SUBCOMMAND_OPTIONS)
      options_storage.transaction do
        @cli.logger.notify 'updating HOSTS key in subcommand_options'
        options_storage['HOSTS'] = cleaned_hosts
      end

      state.transaction do
        state['provisioned'] = true
      end
    end
  end
end
