install = [
  'facter#stable',
  'hiera#stable',
  'puppet#3.7.5'
]

SourcePath  = Beaker::DSL::InstallUtils::SourcePath

PACKAGES = {
  :redhat => [
    'git',
    'ruby',
    'rubygem-json', # :add_el_extras is required to find this package
  ],
  :debian => [
    ['git', 'git-core'],
    'ruby',
  ],
  :debian_ruby18 => [
    'libjson-ruby',
  ],
  :solaris_11 => [
    ['git', 'developer/versioning/git'],
  ],
  :solaris_10 => [
    'coreutils',
    'curl', # update curl to fix "CURLOPT_SSL_VERIFYHOST no longer supports 1 as value!" issue
    'git',
    'ruby19',
    'ruby19_dev',
    'gcc4core',
  ],
  :windows => [
    'git',
  # there isn't a need for json on windows because it is bundled in ruby 1.9
  ],
}

PLATFORM_PATTERNS = {
  :redhat        => /fedora|el|centos/,
  :debian        => /debian|ubuntu/,
  :debian_ruby18 => /debian|ubuntu-lucid|ubuntu-precise/,
  :solaris_10    => /solaris-10/,
  :solaris_11    => /solaris-11/,
  :windows       => /windows/,
}.freeze

# Installs packages on the hosts.
#
# @param hosts [Array<Host>] Array of hosts to install packages to.
# @param package_hash [Hash{Symbol=>Array<String,Array<String,String>>}]
#   Keys should be a symbol for a platform in PLATFORM_PATTERNS.  Values
#   should be an array of package names to install, or of two element
#   arrays where a[0] is the command we expect to find on the platform
#   and a[1] is the package name (when they are different).
# @param options [Hash{Symbol=>Boolean}]
# @option options [Boolean] :check_if_exists First check to see if
#   command is present before installing package.  (Default false)
# @return true
def install_packages_on(hosts, package_hash, options = {})
  return true if hosts == nil
  check_if_exists = options[:check_if_exists]
  hosts = [hosts] unless hosts.kind_of?(Array)
  hosts.each do |host|
    package_hash.each do |platform_key,package_list|
      if pattern = PLATFORM_PATTERNS[platform_key]
        if pattern.match(host['platform'])
          package_list.each do |cmd_pkg|
            if cmd_pkg.kind_of?(Array)
              command, package = cmd_pkg
            else
              command = package = cmd_pkg
            end
            if !check_if_exists || !host.check_for_package(command)
              host.logger.notify("Installing #{package}")
              additional_switches = '--allow-unauthenticated' if platform_key == :debian
              host.install_package(package, additional_switches)
            end
          end
        end
      else
        raise("Unknown platform '#{platform_key}' in package_hash")
      end
    end
  end
  return true
end

install_packages_on(hosts, PACKAGES, :check_if_exists => true)

tmp_repos = []
install.each do |reponame|
  tmp_repos << extract_repo_info_from("https://github.com/puppetlabs/#{reponame}")
end

repos = order_packages(tmp_repos)

hosts.each do |host|
  repos.each do |repo|
    install_from_git(host, SourcePath, repo)
  end
end
