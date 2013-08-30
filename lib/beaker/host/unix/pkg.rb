module Unix::Pkg
  include Beaker::CommandFactory

  def check_for_package name
    result = exec(Beaker::Command.new("which #{name}"), :acceptable_exit_codes => (0...127))
    result.exit_code == 0
  end

  def install_package name
    case self['platform']
      when /el-4/
        @logger.debug("Package installation not supported on rhel4")
      when /fedora|centos|el/
        execute("yum -y install #{name}")
      when /ubuntu|debian/
        execute("apt-get update")
        execute("apt-get install -y #{name}")
      when /solaris/
        execute("pkg install #{name}")
      else
        raise "Package #{name} cannot be installed on #{self}"
    end
  end

end
