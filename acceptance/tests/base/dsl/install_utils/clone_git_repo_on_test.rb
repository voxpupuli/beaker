begin
  $LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'lib'))

  require 'helpers/test_helper'

  require 'beaker/acceptance/install_utils'
  extend Beaker::Acceptance::InstallUtils
end

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

  # build_giturl implicitly looks these up
  ENV['HIERA_FORK']='puppetlabs'
  ENV['FORK']='fail'

  # return a git URL to the named repository, for the supplied host.
  def git_url_for(host, repo_name)
    host.is_cygwin? ? build_git_url(repo_name, nil, nil, 'git') : build_git_url(repo_name)
  end

  # implicitly tests build_giturl() and lookup_in_env()
  hosts.each do |host|
    on host, "echo #{GitHubSig} >> $HOME/.ssh/known_hosts"
    testdir = tmpdir_on(host, File.basename(__FILE__))

    step 'should find fork name from the correct environment variable' do
      results = clone_git_repo_on(host, "#{testdir}", extract_repo_info_from(git_url_for(host, 'puppet')))
      assert_match( %r{github\.com[:/]fail}, result.cmd, 'Did not find correct fork name')
      assert_equal( 1, result.exit_code, 'Did not produce error exit_code of 1')
    end

    step 'should clone hiera from correct fork' do
      results = clone_git_repo_on(host, "#{testdir}", extract_repo_info_from(git_url_for(host, 'hiera')))
      assert_match( %r{From.*github\.com[:/]puppetlabs/hiera}, result.output, 'Did not find clone')
    end
  end
end
