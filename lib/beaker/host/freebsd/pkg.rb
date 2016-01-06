module FreeBSD::Pkg
  include Beaker::CommandFactory

  def install_package(name, cmdline_args = nil, opts = {})
    cmdline_args ||= '-y'
    execute("pkg install #{cmdline_args} #{name}", opts) { |result| result }
  end

  def check_for_package(name, opts = {})
    execute("pkg info #{name}", opts) { |result| result }
  end

end
