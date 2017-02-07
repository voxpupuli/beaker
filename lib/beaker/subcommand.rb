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

    desc "init", "Initialises the beaker test environment configuration"
    option :help, :type => :boolean, :hide => true
    long_desc <<-LONGDESC
    Initialises a beaker environment configuration
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
