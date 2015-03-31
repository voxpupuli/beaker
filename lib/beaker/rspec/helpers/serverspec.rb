require 'serverspec'
require 'specinfra'
require 'specinfra/backend/powershell/script_helper'

# Set specinfra backend to use our custom backend
set :backend, 'BeakerDispatch'

module Specinfra

  # Accessor for current example
  def cur_example
    Specinfra.backend.example
  end

  def get_working_node
    example = cur_example
    if example and example.metadata[:node]
      node = example.metadata[:node]
    else
      node = default_node
    end
    node
  end

  # The cygwin backend
  def cygwin_backend
    @cygwin_backend ||= Specinfra::Backend::BeakerCygwin.instance
  end

  # Backend for everything non-cygwin
  def exec_backend
    @exec_backend ||= Specinfra::Backend::BeakerExec.instance
  end

end


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

module Specinfra::Helper::Os
  private

  # Override detect_os to look at the node platform, short circuit discoverability
  # when we know that we have a windows node
  def detect_os
    return Specinfra.configuration.os if Specinfra.configuration.os
    backend = Specinfra.backend
    node = get_working_node
    if node['platform'] =~ /windows/
      return {:family => 'windows'}
    end
    Specinfra::Helper::DetectOs.subclasses.each do |c|
      res = c.detect
      if res
        res[:arch] ||= Specinfra.backend.run_command('uname -m').stdout.strip
        return res
      end
    end
  end
end

class Specinfra::CommandFactory
  class << self
    # Force creation of a windows command
    def get_windows_cmd(meth, *args)

      action, resource_type, subaction = breakdown(meth)
      method =  action
      method += "_#{subaction}" if subaction

      common_class = Specinfra::Command
      base_class = common_class.const_get('Base')
      os_class = common_class.const_get('Windows')
      version_class = os_class.const_get('Base')
      command_class = version_class.const_get(resource_type.to_camel_case)

      command_class = command_class.create
      if command_class.respond_to?(method)
        command_class.send(method, *args)
      else
        raise NotImplementedError.new("#{method} is not implemented in #{command_class}")
      end
    end

  end
end

module Specinfra
  # Rewrite the runner to use the appropriate backend based upon platform information
  class Runner

    def self.method_missing(meth, *args)
      backend = Specinfra.backend
      node = get_working_node
      if node['platform'] !~ /windows/
        processor = Specinfra::Processor
        if processor.respond_to?(meth)
          processor.send(meth, *args)
        elsif backend.respond_to?(meth)
          backend.send(meth, *args)
        else
          run(meth, *args)
        end
      else
        if backend.respond_to?(meth)
          backend.send(meth, *args)
        else
          run(meth, *args)
        end
      end
    end

    private

    def self.run(meth, *args)
      backend = Specinfra.backend
      cmd = Specinfra.command.get(meth, *args)
      backend = Specinfra.backend
      ret = backend.run_command(cmd)
      if meth.to_s =~ /^check/
        ret.success?
      else
        ret
      end
    end
  end
end

module Specinfra::Backend::PowerShell
  class Command
    # Do a better job at escaping regexes, handle both LF and CRLF (YAY!)
    def convert_regexp(target)
      case target
      when Regexp
        target.source
      else
        Regexp.escape(target.to_s.gsub '/', '\/').gsub('\n', '(\r\n|\n)')
      end
    end
  end
end

module Specinfra::Backend
  class BeakerBase < Specinfra::Backend::Base
    # Example accessor
    def example
      @example
    end

    # Execute the provided ssh command
    # @param [String] command The command to be executed
    # @return [Hash] Returns a hash containing :exit_status, :stdout and :stderr
    def ssh_exec!(node, command)
      r = on node, command, { :acceptable_exit_codes => (0..127) }
      {
        :exit_status => r.exit_code,
        :stdout      => r.stdout,
        :stderr      => r.stderr
      }
    end

  end
end

# Used as a container for the two backends, dispatches as windows/nix depending on node platform
module Specinfra::Backend
  class BeakerDispatch < BeakerBase

    def dispatch_method(meth, *args)
      if get_working_node['platform'] =~ /windows/
        cygwin_backend.send(meth, *args)
      else
        exec_backend.send(meth, *args)
      end
    end

    def run_command(cmd, opts={})
      dispatch_method('run_command', cmd, opts)
    end

    def build_command(cmd)
      dispatch_method('build_command', cmd)
    end

    def add_pre_command(cmd)
      dispatch_method('add_pre_command', cmd)
    end
  end
end

# Backend for running serverspec commands on windows test nodes
module Specinfra::Backend
  class BeakerCygwin < BeakerBase
    include Specinfra::Backend::PowerShell::ScriptHelper

    # Run a windows style command using serverspec.  Defaults to running on the 'default_node'
    # test node, otherwise uses the node specified in @example.metadata[:node]
    # @param [String] cmd The serverspec command to executed
    # @param [Hash] opt No currently supported options
    # @return [Hash] Returns a hash containing :exit_status, :stdout and :stderr
    def run_command(cmd, opt = {})
      node = get_working_node
      script = create_script(cmd)
      on node, "rm -f script.ps1"
      create_remote_file(node, 'script.ps1', script)
      # cygwin support /dev/null, if running from winrm would use < NULL
      ret = ssh_exec!(node, "powershell.exe -File script.ps1 < /dev/null")

      if @example
        @example.metadata[:command] = script
        @example.metadata[:stdout]  = ret[:stdout]
      end

      CommandResult.new ret
    end
  end
end

# Backend for running serverspec commands on non-windows test nodes
module Specinfra::Backend
  class BeakerExec < BeakerBase

    # Run a unix style command using serverspec.  Defaults to running on the 'default_node'
    # test node, otherwise uses the node specified in @example.metadata[:node]
    # @param [String] cmd The serverspec command to executed
    # @param [Hash] opt No currently supported options
    # @return [Hash] Returns a hash containing :exit_status, :stdout and :stderr
    def run_command(cmd, opt = {})
      node = get_working_node
      cmd = build_command(cmd)
      cmd = add_pre_command(cmd)
      ret = ssh_exec!(node, cmd)

      if @example
        @example.metadata[:command] = cmd
        @example.metadata[:stdout]  = ret[:stdout]
      end

      CommandResult.new ret
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
