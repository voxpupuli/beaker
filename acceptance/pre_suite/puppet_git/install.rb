begin
  require 'beaker/acceptance/install_utils'
  extend Beaker::Acceptance::InstallUtils
end
test_name 'Puppet git pre-suite'

install = [
  'facter#2.1.0',
  'hiera#1.3.4',
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
    ['ruby', 'runtime/ruby-18'],
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
  :sles => [
    'git-core',
  ]
}

install_packages_on(hosts, PACKAGES, :check_if_exists => true)

hosts.each do |host|
  case host['platform']
  when /windows/
    arch = host[:ruby_arch] || 'x86'
    step "#{host} Selected architecture #{arch}"

    revision = if arch == 'x64'
                 '2.0.0-x64'
               else
                 '1.9.3-x86'
               end

    step "#{host} Install ruby from git using revision #{revision}"
    # TODO remove this step once we are installing puppet from msi packages
    install_from_git(host, "/opt/puppet-git-repos",
                     :name => 'puppet-win32-ruby',
                     :path => build_giturl('puppet-win32-ruby'),
                     :rev  => revision)
    on host, 'cd /opt/puppet-git-repos/puppet-win32-ruby; cp -r ruby/* /'
    on host, 'cd /lib; icacls ruby /grant "Everyone:(OI)(CI)(RX)"'
    on host, 'cd /lib; icacls ruby /reset /T'
    on host, 'cd /; icacls bin /grant "Everyone:(OI)(CI)(RX)"'
    on host, 'cd /; icacls bin /reset /T'
    on host, 'ruby --version'
    on host, 'cmd /c gem list'
  when /solaris/
    on host, 'gem install json'
  end
end

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
