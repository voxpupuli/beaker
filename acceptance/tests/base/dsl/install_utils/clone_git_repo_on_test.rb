begin
  $LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'lib'))

  require 'helpers/test_helper'

  require 'beaker/acceptance/install_utils'
  extend Beaker::Acceptance::InstallUtils
end
test_name 'Clone from git'
skip_test

PACKAGES = {
  :redhat => [
    'git',
  ],
  :debian => [
    ['git', 'git-core'],
  ],
  :solaris_11 => [
    ['git', 'developer/versioning/git'],
  ],
  :solaris_10 => [
    'coreutils',
    'curl', # update curl to fix "CURLOPT_SSL_VERIFYHOST no longer supports 1 as value!" issue
    'git',
  ],
  :windows => [
    'git',
  ],
  :sles => [
    'git-core',
  ]
}

install_packages_on(hosts, PACKAGES, :check_if_exists => true)

# build_giturl implicitly looks these up
ENV['HIERA_FORK']='puppetlabs'
ENV['FORK']='fail'

# implicitly tests build_giturl() and lookup_in_env()
hosts.each do |host|
  on host, "echo #{GitHubSig} >> $HOME/.ssh/known_hosts"
  testdir = tmpdir_on(host, File.basename(__FILE__))

  step 'should find fork name from the correct environment variable'
  results = clone_git_repo_on(host, "#{testdir}", extract_repo_info_from(build_git_url('puppet')))
  assert_match( /github\.com\/fail/, result.cmd, 'Did not find correct fork name')
  assert_equal( 1, result.exit_code, 'Did not produce error exit_code of 1')

  step 'should clone hiera from correct fork'
  results = clone_git_repo_on(host, "#{testdir}", extract_repo_info_from(build_git_url('hiera')))
  assert_match( /From.*github\.com\/puppetlabs\/hiera/, result.output, 'Did not find clone')
end
