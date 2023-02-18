module Mac::Pkg
  include Beaker::CommandFactory

  def check_for_package(name)
    raise "Package #{name} cannot be queried on #{self}"
  end

  def install_package(name, _cmdline_args = '', _version = nil)
    generic_install_dmg("#{name}.dmg", name, "#{name}.pkg")
  end

  # Install a package from a specified dmg
  #
  # @param [String] dmg_file      The dmg file, including path if not
  #                               relative. Can be a URL.
  # @param [String] pkg_base      The base name of the directory that the dmg
  #                               attaches to under `/Volumes`
  # @param [String] pkg_name      The name of the package file that should be
  #                               used by the installer
  # @example: Install vagrant from URL
  #   mymachost.generic_install_dmg('https://releases.hashicorp.com/vagrant/1.8.4/vagrant_1.8.4.dmg', 'Vagrant', 'Vagrant.pkg')
  def generic_install_dmg(dmg_file, pkg_base, pkg_name)
    execute("test -f #{dmg_file}", :accept_all_exit_codes => true) do |result|
      execute("curl -O #{dmg_file}") unless result.exit_code == 0
    end
    dmg_name = File.basename(dmg_file, '.dmg')
    execute("hdiutil attach #{dmg_name}.dmg")
    execute("installer -pkg /Volumes/#{pkg_base}/#{pkg_name} -target /")
  end

  def uninstall_package(name, _cmdline_args = '')
    raise "Package #{name} cannot be uninstalled on #{self}"
  end

  # Upgrade an installed package to the latest available version
  #
  # @param [String] name          The name of the package to update
  # @param [String] cmdline_args  Additional command line arguments for
  #                               the package manager
  def upgrade_package(name, _cmdline_args = '')
      raise "Package #{name} cannot be upgraded on #{self}"
  end

  # Examine the host system to determine the architecture
  # @return [Boolean] true if x86_64, false otherwise
  def determine_if_x86_64
    result = exec(Beaker::Command.new("uname -a | grep x86_64"), :expect_all_exit_codes => true)
    result.exit_code == 0
  end
end
