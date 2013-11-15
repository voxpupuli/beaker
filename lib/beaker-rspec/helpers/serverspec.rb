require 'serverspec'
require 'serverspec/backend/exec'

module Serverspec
  module Backend
    class BeakerRSpec < Serverspec::Backend::Exec
      def run_command(cmd, opt={})
        cmd = build_command(cmd)
        cmd = add_pre_command(cmd)
        ret = ssh_exec!(cmd)

        if @example
          @example.metadata[:command] = cmd
          @example.metadata[:stdout]  = ret[:stdout]
        end

        ret
      end

      private
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


module Serverspec
  module Helper
    module BeakerRSpec
      def backend(commands_object=nil)
        if ! respond_to?(:commands)
          commands_object = Serverspec::Commands::Base.new
        end
        instance = Serverspec::Backend::BeakerRSpec.instance
        instance.set_commands(commands_object || commands)
        instance
      end
    end
  end
end

include Serverspec::Helper::BeakerRSpec
include Serverspec::Helper::DetectOS
