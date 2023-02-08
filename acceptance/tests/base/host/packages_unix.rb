test_name 'confirm unix-specific package methods work'
confine :except, :platform => %w(windows solaris osx)

current_dir  = File.dirname(__FILE__)
pkg_fixtures = File.expand_path(File.join(current_dir, '../../../fixtures/package'))
pkg_name     = 'puppetserver'

def clean_file(host, file)
  unless file.nil?
    filename = pkg_file(host, file)

    if !filename.nil? && host.file_exist?(filename)
      on(host, "rm -rf #{filename}")
    end
  end
end

def pkg_file(host, pkg_name)
  if /debian|ubuntu/.match?(host['platform'])
    "/etc/apt/sources.list.d/#{pkg_name}.list"
  elsif host['platform'].include?('el')
    "/etc/yum.repos.d/#{pkg_name}.repo"
  else
    nil
  end
end

step '#update_apt_if_needed : can execute without raising an error'
hosts.each do |host|
  host.update_apt_if_needed
end

step '#deploy_apt_repo : deploy puppet-server nightly repo'
hosts.each do |host|

  if /debian|ubuntu/.match?(host['platform'])
    clean_file(host, pkg_name)
    host.deploy_apt_repo(pkg_fixtures, pkg_name, 'latest')
    assert(host.file_exist?(pkg_file(host, pkg_name)), 'apt file should exist')
    clean_file(host, pkg_name)
  end

end

step '#deploy_yum_repo : deploy puppet-server nightly repo'
hosts.each do |host|

  if host['platform'].include?('el')
    clean_file(host, pkg_name)
    host.deploy_yum_repo(pkg_fixtures, pkg_name, 'latest')
    assert(host.file_exist?(pkg_file(host, pkg_name)), 'yum file should exist')
    clean_file(host, pkg_name)
  end

end

step '#deploy_package_repo : deploy puppet-server nightly repo'
hosts.each do |host|
  next if host['platform'].variant == 'sles' && Integer(host['platform'].version) < 12
  host.deploy_package_repo(pkg_fixtures, pkg_name, 'latest')
  clean_file(host, pkg_name)
end
