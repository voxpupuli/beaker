test_name 'confirm packages on hosts behave correctly'
confine :except, :platform => %w(osx)

step '#check_for_command : can determine where a command exists'
hosts.each do |host|
  logger.debug "echo package should be installed on #{host}"
  assert(host.check_for_command('echo'), "'echo' should be a command")
  logger.debug("doesnotexist package should not be installed on #{host}")
  assert_equal(false, host.check_for_command('doesnotexist'), '"doesnotexist" should not be a command')
end

step '#check_for_package : can determine if a package is installed'
hosts.each do |host|
  package = 'bash'

  logger.debug "#{package} package should be installed on #{host}"
  assert(host.check_for_package(package), "'#{package}' should be installed")
  logger.debug("doesnotexist package should not be installed on #{host}")
  assert_equal(false, host.check_for_package('doesnotexist'), '"doesnotexist" should not be installed')
end

step '#install_package and #uninstall_package : remove and install a package successfully'
hosts.each do |host|
  # this works on Windows as well, althought it pulls in
  # a lot of dependencies.
  # skipping this test for windows since it requires a restart
  next if host['platform'].include?('windows')

  package = 'zsh'
  package = 'git' if /opensuse|sles/.match?(host['platform'])

  assert_equal(false, host.check_for_package(package), "'#{package}' not should be installed")
  logger.debug("#{package} should be installed on #{host}")
  cmdline_args = ''
  # Newer vmpooler hosts created by Packer templates, and running Cygwin 2.4,
  # must have these switches passed
  cmdline_args = '--local-install --download' if (host['platform'].include?('windows') and host.is_cygwin?)
  host.install_package(package, cmdline_args)
  assert(host.check_for_package(package), "'#{package}' should be installed")

  # windows does not support uninstall_package
  unless host['platform'].include?('windows')
    logger.debug("#{package} should be uninstalled on #{host}")
    host.uninstall_package(package)
    if host['platform'].include?('debian')
      assert_equal(false, host.check_for_command(package), "'#{package}' should not be installed or available")
    else
      assert_equal(false, host.check_for_package(package), "'#{package}' should not be installed")
    end
  end
end
