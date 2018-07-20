module FreeBSD::Pkg
  include Beaker::CommandFactory

  def pkg_info_pattern(package)
    # This seemingly restrictive pattern prevents false positives...
    "^#{package}-[0-9][0-9a-zA-Z_\\.,]*$"
  end

  def check_pkgng_sh
    'TMPDIR=/dev/null ASSUME_ALWAYS_YES=1 PACKAGESITE=file:///nonexist ' \
    'pkg info -x "pkg(-devel)?\\$" > /dev/null 2>&1'
  end

  def pkgng_active?(opts = {})
    opts = {:accept_all_exit_codes => true}.merge(opts)
    execute("/bin/sh -c '#{check_pkgng_sh}'", opts) { |r| r }.exit_code == 0
  end

  def install_package(package, cmdline_args = nil, opts = {})
    cmd = if pkgng_active?
            "pkg install #{cmdline_args || '-y'} #{package}"
          else
            "pkg_add #{cmdline_args || '-r'} #{package}"
          end
    execute(cmd, opts) { |result| result }
  end

  def uninstall_package(package, cmdline_args = nil, opts = {})
    cmd = if pkgng_active?
            "pkg delete #{cmdline_args || '-y'} #{package}"
          else
            "pkg_delete #{cmdline_args || '-r'} #{package}"
          end
    execute(cmd, opts) { |result| result }
  end

  def check_for_package(package, opts = {})
    opts = {:accept_all_exit_codes => true}.merge(opts)
    cmd = if pkgng_active?
            "pkg info #{package}"
          else
            "pkg_info -Ix '#{pkg_info_pattern(package)}'"
          end
    execute(cmd, opts) { |result| result }.exit_code == 0
  end
end
