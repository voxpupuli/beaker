module Unix::Pkg
  include Beaker::CommandFactory

  def check_for_package(name)
    result = exec(Beaker::Command.new("which #{name}"), :acceptable_exit_codes => (0...127))
    result.exit_code == 0
  end

  def install_package(name, cmdline_args = '')
    case self['platform']
      when /el-4/
        @logger.debug("Package installation not supported on rhel4")
      when /fedora|centos|el/
        execute("yum -y #{cmdline_args} install #{name}")
      when /ubuntu|debian/
        execute("apt-get update")
        execute("apt-get install #{cmdline_args} -y #{name}")
      when /solaris/
        execute("pkg #{cmdline_args} install #{name}")
      else
        raise "Package #{name} cannot be installed on #{self}"
    end
  end

  def uninstall_package(name, cmdline_args = '')
    case self['platform']
      when /el-4/
        @logger.debug("Package uninstallation not supported on rhel4")
      when /fedora|centos|el/
        execute("yum -y #{cmdline_args} remove #{name}")
      when /ubuntu|debian/
        execute("apt-get purge #{cmdline_args} -y #{name}")
      when /solaris/
        execute("pkgrm #{cmdline_args} #{name}")
      else
        raise "Package #{name} cannot be installed on #{self}"
    end
  end
end
