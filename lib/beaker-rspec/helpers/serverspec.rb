require 'serverspec'
require 'specinfra'

# Set specinfra backend to use our custom backend
set :backend, 'BeakerExec'

# Override existing specinfra configuration to avoid conflicts
# with beaker's shell, stdout, stderr defines
module Specinfra
  module Configuration
    class << self
      VALID_OPTIONS_KEYS = [
        :backend,
        :env,
        :path,
        :pre_command,
        :sudo_path,
        :disable_sudo,
        :sudo_options,
        :docker_image,
        :docker_url,
        :lxc,
        :request_pty,
        :ssh_options,
        :dockerfile_finalizer,
      ].freeze
    end
  end
end

module Specinfra::Backend
  class BeakerExec < Specinfra::Backend::Base
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

    def build_command(cmd)
      useshell = '/bin/sh'
      cmd = cmd.shelljoin if cmd.is_a?(Array)
      cmd = "#{useshell.shellescape} -c #{cmd.shellescape}"

      path = Specinfra.configuration.path
      if path
        cmd = %Q{env PATH="#{path}" #{cmd}}
      end

      cmd
    end

    def add_pre_command(cmd)
      if Specinfra.configuration.pre_command
        pre_cmd = build_command(Specinfra.configuration.pre_command)
        "#{pre_cmd} && #{cmd}"
      else
        cmd
      end
    end

  end
end
