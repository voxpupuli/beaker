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

  def exec(host, options={})
    host.exec(cmd_line(host), options[:stdin])
  end

  # Determine the appropriate puppet env command for the given host.
  def puppet_env_command(host_info)
    %Q{env RUBYLIB="#{host_info['puppetlibdir']||''}:#{host_info['facterlibdir']||''}" PATH="#{host_info['puppetbindir']||''}:#{host_info['facterbindir']||''}:$PATH"}
  end
end

class PuppetCommand < Command
  def initialize(sub_command, *args)
    @sub_command = sub_command
    @options = args.last.is_a?(Hash) ? args.pop : {}
    # Dom: commenting these lines addressed bug #6920
    # @options[:vardir] ||= '/tmp'
    # @options[:confdir] ||= '/tmp'
    # @options[:ssldir] ||= '/tmp'
    @args = args
  end

  def cmd_line(host_info)
    puppet_path = host_info[:puppetbinpath] || "/bin/puppet" # TODO: is this right?

    args_string = (@args + @options.map { |key, value| "--#{key}=#{value}" }).join(' ')
    "#{puppet_env_command(host_info)} puppet #{@sub_command} #{args_string}"
  end
end

class FacterCommand < Command
  def initialize(*args)
    @args = args
  end

  def cmd_line(host_info)
    args_string = @args.join(' ')
    "#{puppet_env_command(host_info)} facter #{args_string}"
  end
end
