require "thor"
require "fileutils"
require "beaker/subcommands/subcommand_util"

module Beaker
  class Subcommand < Thor
    SubcommandUtil = Beaker::Subcommands::SubcommandUtil

    desc "init", "Initialises the beaker test environment configuration"
    option :hypervisor, :type => :string, :required => true
    long_desc <<-LONGDESC
      Initialises a beaker environment configuration
    LONGDESC
    def init()
      SubcommandUtil.verify_init_args(options)
      SubcommandUtil.require_tasks()
      SubcommandUtil.init_hypervisor(options)
    end
  end
end
