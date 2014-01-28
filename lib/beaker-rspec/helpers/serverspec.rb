require 'serverspec'
require 'specinfra'
require 'specinfra/backend/exec'

module SpecInfra
  # Backend Module
  #
  # Contains the bridge between beaker-rspec and serverspec
  module Backend
    # Class BeakerExec
    #
    # Controls the running of Serverspec commands.
    class BeakerExec < SpecInfra::Backend::Exec
      # Run a command using serverspec.  Defaults to running on the 'default' test node, otherwise uses the
      # node specified in @example.metadata[:node]
      # @param [String] cmd The serverspec command to executed
      # @param [Hash] opt No currently supported options
      # @return [Hash] Returns a hash containing :exit_status, :stdout and :stderr
      def run_command(cmd, opt={})
        cmd = build_command(cmd)
        cmd = add_pre_command(cmd)
        ret = ssh_exec!(cmd)

        if @example
          @example.metadata[:command] = cmd
          @example.metadata[:stdout]  = ret[:stdout]
        end

        CommandResult.new ret
      end

      private
      # Execute the provided ssh command
      # @param [String] command The command to be executed
      # @return [Hash] Returns a hash containing :exit_status, :stdout and :stderr
      def ssh_exec!(command)
        if @example and @example.metadata[:node]
          node = @example.metadata[:node]
        else
          node = default
        end

        r = on node, command, { :acceptable_exit_codes => (0..127) }
        {
          :exit_status => r.exit_code,
          :stdout      => r.stdout,
          :stderr      => r.stderr
        }
      end
    end
  end
end


module SpecInfra
  # Helper Module
  #
  #
  module Helper
    # BeakerBackend Module
    #
    module BeakerBackend
      # @param commands_object [Object] The command object
      # @return [SpecInfra::Backend::BeakerExec] Returns an instance of SpecInfra::Backend::BeakerExec
      def backend(commands_object=nil)
        if ! respond_to?(:commands)
          commands_object = SpecInfra::Commands::Base.new
        end
        instance = SpecInfra::Backend::BeakerExec.instance
        instance.set_commands(commands_object || commands)
        instance
      end
    end
  end
end

include SpecInfra::Helper::BeakerBackend
include SpecInfra::Helper::DetectOS
