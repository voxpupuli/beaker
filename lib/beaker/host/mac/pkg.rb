module Mac::Pkg
  include Beaker::CommandFactory

  def check_for_package(name)
    raise "Package #{name} cannot be queried on #{self}"
  end

  def install_package(name, _cmdline_args = '', _version = nil)
    # strip off any .dmg extension, if it exists
    name = File.basename(name, '.dmg')
    generic_install_dmg("#{name}.dmg", name, "#{name}.pkg")
  end

  # Install a package from a specified dmg
  #
  # @param [String] dmg_file      The dmg file, including path if not
  #                               relative. Can be a URL.
  # @param [String] pkg_base      The base name of the directory that the dmg
  #                               attaches to under `/Volumes`
  # @param [String] pkg_name      The name of the package file that should be
  #                               used by the installer. If the specified
  #                               package is not found, a wildcard search will be
  #                               performed to locate and install the first `.pkg`
  #                               file in the volume.
  # @example: Install vagrant from URL
  #   mymachost.generic_install_dmg('https://releases.hashicorp.com/vagrant/1.8.4/vagrant_1.8.4.dmg', 'Vagrant', 'Vagrant.pkg')
  def generic_install_dmg(dmg_file, pkg_base, pkg_name)
    execute("test -f #{dmg_file}", :accept_all_exit_codes => true) do |result|
      execute("curl -O #{dmg_file}") unless result.exit_code == 0
    end
    dmg_name = File.basename(dmg_file, '.dmg')
    execute("hdiutil attach #{dmg_name}.dmg")

    # First check if the specific package exists, otherwise use wildcard
    specific_pkg_path = "/Volumes/#{pkg_base}/#{pkg_name}"
    execute("test -f #{specific_pkg_path}", :accept_all_exit_codes => true) do |result|
      if result.exit_code == 0
        # $pkg_name package found so install it
        execute("installer -pkg #{specific_pkg_path} -target /")
      else
        # else find and install the first *.pkg file in the volume
        execute <<~SCRIPT
          # find the first .pkg file in the mounted volume
          pkg=$(find /Volumes/#{pkg_base} -name "*.pkg" -type f -print -quit)
          if [ -n "$pkg" ]; then
            echo "Installing $pkg"
            installer -pkg "$pkg" -target /
          else
            echo "ERROR: No .pkg files found in /Volumes/#{pkg_base}/"
            exit 1
          fi
        SCRIPT
      end
    end
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
end
