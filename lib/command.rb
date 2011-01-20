# An immutable data structure representing a task to run on a remote
# machine.
class Command
  def initialize(command_string)
    @command_string = command_string
  end

  # host_info is a hash-like object that can be queried to figure out
  # properties of the host.
  def cmd_line(host_info)
    @command_string
  end
end

class PuppetCommand < Command
  def initialize(sub_command, *args)
    @sub_command = sub_command
    @options = args.last.is_a?(Hash) ? args.pop : {}
    @options[:vardir] ||= '/tmp'
    @options[:confdir] ||= '/tmp'
    @options[:ssldir] ||= '/tmp'
    @args = args
  end

  def cmd_line(host_info)
    puppet_env_command = %Q{env RUBYLIB="#{host_info['puppetlibdir']||''}:#{host_info['facterlibdir']||''}" PATH="#{host_info['puppetbindir']||''}:#{host_info['facterbindir']||''}:$PATH"}
    puppet_path = host_info[:puppetbinpath] || "/bin/puppet" # TODO: is this right?

    args_string = (@args + @options.map { |key, value| "--#{key}=#{value}" }).join(' ')
    "#{puppet_env_command} puppet #{@sub_command} #{args_string}"
  end
end

