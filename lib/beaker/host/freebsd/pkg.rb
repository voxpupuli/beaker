module FreeBSD::Pkg
  include Beaker::CommandFactory

  def install_package(name, cmdline_args = nil, opts = {})
    case self['platform']
    when /freebsd-9/
      cmdline_args ||= '-rF'
      result = execute("pkg_add #{cmdline_args} #{name}", opts) { |result| result }
    when /freebsd-10/
      cmdline_args ||= '-y'
      result = execute("pkg install #{cmdline_args} #{name}", opts) { |result| result }
    else
      raise "Package #{name} could not be installed on #{self}"
    end
    result.exit_code == 0
  end

end
