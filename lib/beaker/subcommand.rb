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
    class_option :'debug-errors', :type => :boolean, :group => 'Beaker run'

    # The following are listed as deprecated in beaker --help, but needed now for
    # feature parity for beaker 3.x.
    class_option :xml, :type => :boolean, :group => "Beaker run"
    class_option :type, :type => :string, :group => "Beaker run"
    class_option :debug, :type => :boolean, :group => "Beaker run"

    desc "init BEAKER_RUN_OPTIONS", "Initializes the required configuration for Beaker subcommand execution"
    long_desc <<-LONGDESC
      Initializes the required .beaker configuration folder. This folder contains
      a subcommand_options.yaml file that is user-facing; altering this file will
      alter the options subcommand execution. Subsequent subcommand execution,
      such as `provision`, will result in beaker making modifications to this file
      as necessary.
    LONGDESC
    option :help, :type => :boolean, :hide => true
    method_option :hosts, :aliases => '-h', :type => :string, :required => true
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

      @cli.logger.notify 'Writing configured options to disk'
      File.open(SubcommandUtil::SUBCOMMAND_OPTIONS, 'w') do |f|
        f.write(options_to_write.to_yaml)
      end
      @cli.logger.notify "Options written to #{SubcommandUtil::SUBCOMMAND_OPTIONS}"

      state = YAML::Store.new(SubcommandUtil::SUBCOMMAND_STATE)
      state.transaction do
        state['provisioned'] = false
      end
    end

    desc "provision", "Provisions the beaker systems under test(SUTs)"
    long_desc <<-LONGDESC
    Provisions hosts defined in your subcommand_options file. You can pass the --hosts
    flag here to override any hosts provided there. Really, you can pass most any beaker
    flag here to override.
    LONGDESC
    option :help, :type => :boolean, :hide => true
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

      # Update each host provisioned with a flag indicating that it no longer needs
      # provisioning
      cleaned_hosts.each do |host, host_hash|
        host_hash['provision'] = false
      end

      # should we only update the options here with the new host? Or update the settings
      # with whatever new flags may have been provided with provision?
      options_storage = YAML::Store.new(SubcommandUtil::SUBCOMMAND_OPTIONS)
      options_storage.transaction do
        @cli.logger.notify 'updating HOSTS key in subcommand_options'
        options_storage['HOSTS'] = cleaned_hosts
        options_storage['hosts_preserved_yaml_file'] = @cli.options[:hosts_preserved_yaml_file]
      end

      @cli.preserve_hosts_file

      state.transaction do
        state['provisioned'] = true
      end
    end

    desc 'exec FILE/BEAKER_SUITE', 'execute a directory, file, or beaker suite'
    long_desc <<-LONG_DESC
    Run a single file, directory, or beaker suite. If supplied a file or directory,
    that resource will be run in the context of the `tests` suite; If supplied a beaker
    suite, then just that suite will run. If no resource is supplied, then this command
    executes the suites as they are defined in the configuration.
    LONG_DESC
    option :help, :type => :boolean, :hide => true
    def exec(resource=nil)
      if options[:help]
        invoke :help, [], ["exec"]
        return
      end

      @cli.parse_options
      @cli.initialize_network_manager

      if !resource
        @cli.execute!
        return
      end

      beaker_suites = [:pre_suite, :tests, :post_suite, :pre_cleanup]

      if Pathname(resource).exist?
        # If we determine the resource is a valid file resource, then we empty
        # all the suites and run that file resource in the tests suite. In the
        # future, when we have the ability to have custom suites, we should change
        # this to run in a custom suite. You know, in the future.
        beaker_suites.each do |suite|
          @cli.options[suite] = []
        end
        if Pathname(resource).directory?
          @cli.options[:tests] = Dir.glob("#{Pathname(resource).expand_path}/*.rb")
        else
          @cli.options[:tests] = [Pathname(resource).expand_path.to_s]
        end
      elsif resource.match(/pre-suite|tests|post-suite|pre-cleanup/)
        # The regex match here is loose so that users can supply multiple suites,
        # such as `beaker exec pre-suite,tests`.
        beaker_suites.each do |suite|
          @cli.options[suite] = [] unless resource.gsub(/-/, '_').match(suite.to_s)
        end
      else
        raise ArgumentError, "Unable to parse #{resource} with beaker exec"
      end
      @cli.execute!
    end

    desc "destroy", "Destroys the provisioned VMs"
    long_desc <<-LONG_DESC
    Destroys the currently provisioned VMs
    LONG_DESC
    option :help, :type => :boolean, :hide => true
    def destroy()
      if options[:help]
        invoke :help, [], ["destroy"]
        return
      end

      state = YAML::Store.new(SubcommandUtil::SUBCOMMAND_STATE)
      unless state.transaction { state['provisioned']}
        SubcommandUtil.error_with('Please provision an environment')
      end

      @cli.parse_options
      @cli.options[:provision] = false
      @cli.initialize_network_manager
      @cli.network_manager.cleanup

      state.transaction {
        state.delete('provisioned')
      }
    end
  end
end
