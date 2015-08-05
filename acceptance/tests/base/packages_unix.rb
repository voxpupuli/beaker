test_name 'confirm unix-specific package methods work'
confine :except, :platform => %w(windows solaris)

current_dir  = File.dirname(__FILE__)
pkg_fixtures = File.expand_path(File.join(current_dir, '../../fixtures/package'))
pkg_name     = 'puppetserver'

def clean_file(host, file)
  if host.file_exist?(file)
    on(host, "rm -rf #{file}")
  end
end

step '#update_apt_if_needed : can execute without raising an error'
hosts.each do |host|
  host.update_apt_if_needed
end

step '#deploy_apt_repo : deploy puppet-server nightly repo'
hosts.each do |host|

  if host['platform'] =~ /debian|ubuntu/
    pkg_file = "/etc/apt/sources.list.d/#{pkg_name}.list"

    clean_file(host, pkg_file)
    host.deploy_apt_repo(pkg_fixtures, 'puppetserver', 'latest')
    assert_equal(true, host.file_exist?(pkg_file), 'apt file should exist')
    clean_file(host, pkg_file)
  end

end

step '#deploy_yum_repo : deploy puppet-server nightly repo'
hosts.each do |host|

  if host['platform'] =~ /el/
    pkg_file = "/etc/yum.repos.d/#{pkg_name}.repo"

    clean_file(host, pkg_file)
    host.deploy_yum_repo(pkg_fixtures, pkg_name, 'latest')
    assert_equal(true, host.file_exist?(pkg_file), 'yum file should exist')
    clean_file(host, pkg_file)
  end

end

step '#deploy_package_repo : deploy puppet-server nightly repo'
hosts.each do |host|
  host.deploy_package_repo(pkg_fixtures, 'puppetserver', 'latest')
end
