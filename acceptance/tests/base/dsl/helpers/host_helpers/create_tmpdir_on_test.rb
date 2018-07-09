require "helpers/test_helper"

test_name "dsl::helpers::host_helpers #create_tmpdir_on" do
  step "#create_tmpdir_on returns a temporary directory on the remote system" do
    tmpdir = create_tmpdir_on default
    assert_match %r{/}, tmpdir
    assert_equal 0, on(default, "touch #{tmpdir}/testfile").exit_code
  end

  step "#create_tmpdir_on uses the specified path prefix when provided" do
    tmpdir = create_tmpdir_on(default, "mypathprefix")
    assert_match %r{/mypathprefix}, tmpdir
    assert_equal 0, on(default, "touch #{tmpdir}/testfile").exit_code
  end

  step "#create_tmpdir_on fails if a non-existent user is specified" do
    assert_raises Beaker::Host::CommandFailure do
      tmpdir = create_tmpdir_on default, '', 'fakeuser'
    end
  end

  step "#create_tmpdir_on sets the user if specified" do
    default.user_present('tmpdirtestuser')
    tmpdir = create_tmpdir_on(default, nil, 'tmpdirtestuser', nil)
    assert_match /tmpdirtestuser/, on(default, "ls -ld #{tmpdir}").output
    default.user_absent('tmpdirtestuser')
  end

  step "#create_tmpdir_on fails if a non-existent group is specified" do
    assert_raises Beaker::Host::CommandFailure do
      tmpdir = create_tmpdir_on default, '', nil, 'fakegroup'
    end
  end

  step "#create_tmpdir_on sets the group if specified" do
    default.group_present('tmpdirtestgroup')
    tmpdir = create_tmpdir_on(default, nil, nil, 'tmpdirtestgroup')
    assert_match /testgroup/, on(default, "ls -ld #{tmpdir}").output
    default.group_absent('tmpdirtestgroup')
  end

  step "#create_tmpdir_on operates on all hosts if given a hosts array" do
    tmpdirs = create_tmpdir_on hosts
    hosts.zip(tmpdirs).each do |(host, tmpdir)|
      assert_match %r{/}, tmpdir
      assert_equal 0, on(host, "touch #{tmpdir}/testfile").exit_code
    end
  end
end
