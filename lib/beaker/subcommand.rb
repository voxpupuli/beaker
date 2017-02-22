require "thor"
require "fileutils"
require "beaker/subcommands/subcommand_util"

module Beaker
  class Subcommand < Thor
    SubcommandUtil = Beaker::Subcommands::SubcommandUtil

    desc "init", "Initialises the beaker test environment configuration"
    option :hypervisor, :type => :string, :enum => %w{vagrant vmpooler}
    option :help, :type => :boolean, :hide => true
    long_desc <<-LONGDESC
      Initialises a beaker environment configuration
    LONGDESC
    def init()
      if options[:help]
        invoke :help, [], ["init"]
        return
      end
      SubcommandUtil.require_tasks()
      SubcommandUtil.init_hypervisor(options)
      say "Writing host config to .beaker/acceptance/config/default_#{options[:hypervisor]}_hosts.yaml"
    end
  end
end
