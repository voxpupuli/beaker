require "helpers/test_helper"

test_name "dsl::helpers::host_helpers #create_tmpdir_on" do

  # NOTE: there does not seem to be a reliable way to confine to cygwin hosts.
  confine_block :to, :platform => /windows/ do

    step "#create_tmpdir_on CURRENTLY fails when attempting to chown the created tempdir to the host user + group, on windows platforms" do
      # NOTE: would have expected this to work.
      # TODO: fix via https://tickets.puppetlabs.com/browse/BKR-496

      assert_raises Beaker::Host::CommandFailure do
        tmpdir = create_tmpdir_on default
      end
    end
  end

  confine_block :to, :platform => /osx/ do

    step "#create_tmpdir_on CURRENTLY fails when attempting to call getent to check the creating user" do
      # NOTE: would have expected this to work.
      # TODO: fix via https://tickets.puppetlabs.com/browse/BKR-496

      assert_raises Beaker::Host::CommandFailure do
        tmpdir = create_tmpdir_on default
      end
    end
  end

  confine_block :except, :platform => /windows|osx/ do

    step "#create_tmpdir_on chowns the created tempdir to the host user + group" do
      tmpdir = create_tmpdir_on default
      listing = on(default, "ls -al #{tmpdir}").stdout
      tmpdir_ls = listing.split("\n").grep %r{\s+\./?\s*$}
      assert_equal 1, tmpdir_ls.size
      perms, inodes, owner, group, *rest = tmpdir_ls.first.split(/\s+/)
      assert_equal default['user'], owner
      assert_equal default['user'], group
    end

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
        tmpdir = create_tmpdir_on default, '', "fakeuser"
      end
    end

    step "#create_tmpdir_on operates on all hosts if given a hosts array" do
      tmpdirs = create_tmpdir_on hosts
      hosts.zip(tmpdirs).each do |(host, tmpdir)|
        assert_match %r{/}, tmpdir
        assert_equal 0, on(host, "touch #{tmpdir}/testfile").exit_code
      end
    end
  end
end
