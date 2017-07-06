begin
  $LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'lib'))

  require 'helpers/test_helper'

  require 'beaker/acceptance/install_utils'
  extend Beaker::Acceptance::InstallUtils
end

confine :except, :platform => /^solaris-10/

test_name 'Clone from git' do

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

  # implicitly tests build_giturl() and lookup_in_env()
  hosts.each do |host|
    on host, "echo #{GitHubSig} >> $HOME/.ssh/known_hosts"
    testdir = tmpdir_on(host, File.basename(__FILE__))

    step 'should be able to successfully clone a git repo' do
      results = clone_git_repo_on(host, "#{testdir}", extract_repo_info_from(build_git_url('hiera')))
      assert_match( %r{From.*github\.com[:/]puppetlabs/hiera}, result.output, 'Did not find clone')
    end
  end
end
