require "thor"
require "fileutils"
require "beaker/subcommands/subcommand_util"

module Beaker
  class Subcommand < Thor
    SubcommandUtil = Beaker::Subcommands::SubcommandUtil

    def initialize(*args)
      super
      @@config = SubcommandUtil.init_config()
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

    desc "init HYPERVISOR", "Initialises the beaker test environment configuration"
    option :help, :type => :boolean, :hide => true
    long_desc <<-LONGDESC

      Initialises a test environment configuration for a specific hypervisor

      Supported hypervisors are: vagrant (default), vmpooler

    LONGDESC
    def init(hypervisor='vagrant')
      if options[:help]
        invoke :help, [], ["init"]
        return
      end
      SubcommandUtil.verify_init_args(hypervisor)
      SubcommandUtil.require_tasks()
      SubcommandUtil.init_hypervisor(hypervisor)
      say "Writing host config to .beaker/acceptance/config/default_#{hypervisor}_hosts.yaml"
      SubcommandUtil.store_config({:hypervisor => hypervisor})
      SubcommandUtil.delete_config([:provisioned])
    end

    desc "provision", "Provisions the beaker test configuration"
    option :validate, :type => :boolean, :default => true
    option :configure, :type => :boolean, :default => true
    option :help, :type => :boolean, :hide => true
    long_desc <<-LONGDESC
    Provisions a beaker configuration
    LONGDESC
    def provision()
      if options[:help]
        invoke :help, [], ["provision"]
        return
      end

      hypervisor = @@config.transaction { @@config[:hypervisor] }

      unless hypervisor
        SubcommandUtil.error_with("Please initialise a configuration")
      end

      provisioned = @@config.transaction { @@config[:provisioned] }

      if !provisioned or options[:force]
        SubcommandUtil.provision(hypervisor, options)
        SubcommandUtil.store_config({:provisioned => true})
      else
        say "Hosts have already been provisioned"
      end
    end
  end
end
