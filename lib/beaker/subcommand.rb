require "thor"
require "fileutils"
require "beaker/subcommands/subcommand_util"

module Beaker
  class Subcommand < Thor
    SubcommandUtil = Beaker::Subcommands::SubcommandUtil

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
      if %w(vagrant vmpooler).include?(hypervisor)
        SubcommandUtil.require_tasks()
        SubcommandUtil.init_hypervisor(hypervisor)
        say "Writing host config to .beaker/acceptance/config/default_#{hypervisor}_hosts.yaml"
      else
        SubcommandUtil.error_with("You did not enter a supported hypervisor.  Please enter 'vagrant' or 'vmpooler'.")
      end

    end
  end
end
