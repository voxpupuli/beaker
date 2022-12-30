require "helpers/test_helper"

test_name "dsl::helpers::host_helpers #run_cron_on" do

  confine_block :to, :platform => /windows/ do

    step "#run_cron_on fails on windows platforms when listing cron jobs for a user on a host" do
      assert_raises Beaker::Host::CommandFailure do
        run_cron_on default, :list, default['user']
      end
    end
  end

  confine_block :to, :platform => /solaris/ do

    step "#run_cron_on CURRENTLY does nothing and returns `nil` when an unknown command is provided" do
      # NOTE: would have expected this to raise Beaker::Host::CommandFailure instead

      assert_nil run_cron_on default, :nonexistent_action, default['user']
    end

    step "#run_cron_on CURRENTLY does not fail when listing cron jobs for an unknown user" do
      assert_raises Beaker::Host::CommandFailure do
        run_cron_on default, :list, "nonexistentuser"
      end
    end

    step "#run_cron_on CURRENTLY does not fail when listing cron jobs for a user with no cron entries" do
      result = run_cron_on default, :list, default['user']
      assert_equal 0, result.exit_code
    end

    step "#run_cron_on returns a list of cron jobs for a user with cron entries" do
      # this basically requires us to add a cron entry to make this work
      run_cron_on default, :add, default['user'], "* * * * * /bin/ls >/dev/null"
      result = run_cron_on default, :list, default['user']
      assert_equal 0, result.exit_code
      assert_match %r{/bin/ls}, result.stdout
    end

    step "#run_cron_on CURRENTLY does not fail, but returns nil, when adding cron jobs for an unknown user" do
      result = run_cron_on default, :add, "nonexistentuser", %Q{* * * * * /bin/echo "hello" >/dev/null}
      assert_nil result
    end

    step "#run_cron_on CURRENTLY does not fail, but returns nil, when attempting to add a bad cron entry" do
      result = run_cron_on default, :add, default['user'], "* * * * /bin/ls >/dev/null"
      assert_nil result
    end

    step "#run_cron_on can add a cron job for a user on a host" do
      run_cron_on default, :add, default['user'], %Q{* * * * * /bin/echo "hello" >/dev/null}
      result = run_cron_on default, :list, default['user']
      assert_equal 0, result.exit_code
      assert_match %r{/bin/echo}, result.stdout
    end

    step "#run_cron_on CURRENTLY replaces all of user's cron jobs with any newly added jobs" do
      # NOTE: would have expected this to append new entries, or manage them as puppet manages
      #       cron entries.  See also: https://github.com/puppetlabs/beaker/pull/937#discussion_r38338494

      1.upto(3) do |job_number|
        run_cron_on default, :add, default['user'], %Q{* * * * * /bin/echo "job :#{job_number}:" >/dev/null}
      end

      result = run_cron_on default, :list, default['user']

      assert_no_match %r{job :1:}, result.stdout
      assert_no_match %r{job :2:}, result.stdout
      assert_match %r{job :3:}, result.stdout
    end

    step "#run_cron_on :remove CURRENTLY removes all cron jobs for a user on a host" do
      # NOTE: would have expected a more granular approach to removing cron jobs
      #       for a user on a host.  This should otherwise be better documented.

      run_cron_on default, :add, default['user'], %Q{* * * * * /bin/echo "quality: job 1" >/dev/null}
      result = run_cron_on default, :list, default['user']
      assert_match %r{quality: job 1}, result.stdout

      run_cron_on default, :remove, default['user']

      assert_raises Beaker::Host::CommandFailure do
        run_cron_on default, :list, default['user']
      end
    end

    step "#run_cron_on fails when removing cron jobs for an unknown user" do
      assert_raises Beaker::Host::CommandFailure do
        run_cron_on default, :remove, "nonexistentuser"
      end
    end

    step "#run_cron_on can list cron jobs for a user on all hosts when given a host array" do
      hosts.each do |host|
        # this basically requires us to add a cron entry to make this work
        run_cron_on host, :add, host['user'], "* * * * * /bin/ls >/dev/null"
      end

      results = run_cron_on hosts, :list, default['user']
      results.each do |result|
        assert_match %r{/bin/ls}, result.stdout
      end
    end

    step "#run_cron_on can add cron jobs for a user on all hosts when given a host array" do
      run_cron_on hosts, :add, default['user'], "* * * * * /bin/ls >/dev/null"

      results = run_cron_on hosts, :list, default['user']
      results.each do |result|
        assert_match %r{/bin/ls}, result.stdout
      end
    end

    step "#run_cron_on can remove cron jobs for a user on all hosts when given a host array" do
      run_cron_on hosts, :add, default['user'], "* * * * * /bin/ls >/dev/null"
      run_cron_on hosts, :remove, default['user']

      hosts.each do |host|
        assert_raises Beaker::Host::CommandFailure do
          run_cron_on host, :list, host['user']
        end
      end
    end
  end

  confine_block :except, :platform => /windows|solaris/ do

    step "#run_cron_on CURRENTLY does nothing and returns `nil` when an unknown command is provided" do
      # NOTE: would have expected this to raise Beaker::Host::CommandFailure instead

      assert_nil run_cron_on default, :nonexistent_action, default['user']
    end

    step "#run_cron_on fails when listing cron jobs for an unknown user" do
      assert_raises Beaker::Host::CommandFailure do
        run_cron_on default, :list, "nonexistentuser"
      end
    end

    step "#run_cron_on fails when listing cron jobs for a user with no cron entries" do
      assert_raises Beaker::Host::CommandFailure do
        run_cron_on default, :list, default['user']
      end
    end

    step "#run_cron_on returns a list of cron jobs for a user with cron entries" do
      # this basically requires us to add a cron entry to make this work
      run_cron_on default, :add, default['user'], "* * * * * /bin/ls >/dev/null"
      result = run_cron_on default, :list, default['user']
      assert_equal 0, result.exit_code
      assert_match %r{/bin/ls}, result.stdout
    end

    step "#run_cron_on fails when adding cron jobs for an unknown user" do
      assert_raises Beaker::Host::CommandFailure do
        run_cron_on default, :add, "nonexistentuser", %Q{* * * * * /bin/echo "hello" >/dev/null}
      end
    end

    step "#run_cron_on fails when attempting to add a bad cron entry" do
      assert_raises Beaker::Host::CommandFailure do
        run_cron_on default, :add, default['user'], "* * * * /bin/ls >/dev/null"
      end
    end

    step "#run_cron_on can add a cron job for a user on a host" do
      run_cron_on default, :add, default['user'], %Q{* * * * * /bin/echo "hello" >/dev/null}
      result = run_cron_on default, :list, default['user']
      assert_equal 0, result.exit_code
      assert_match %r{/bin/echo}, result.stdout
    end

    step "#run_cron_on CURRENTLY replaces all of user's cron jobs with any newly added jobs" do
      # NOTE: would have expected this to append new entries, or manage them as puppet manages
      #       cron entries.  See also: https://github.com/puppetlabs/beaker/pull/937#discussion_r38338494

      1.upto(3) do |job_number|
        run_cron_on default, :add, default['user'], %Q{* * * * * /bin/echo "job :#{job_number}:" >/dev/null}
      end

      result = run_cron_on default, :list, default['user']

      assert_no_match %r{job :1:}, result.stdout
      assert_no_match %r{job :2:}, result.stdout
      assert_match %r{job :3:}, result.stdout
    end

    step "#run_cron_on :remove CURRENTLY removes all cron jobs for a user on a host" do
      # NOTE: would have expected a more granular approach to removing cron jobs
      #       for a user on a host.  This should otherwise be better documented.

      run_cron_on default, :add, default['user'], %Q{* * * * * /bin/echo "quality: job 1" >/dev/null}
      result = run_cron_on default, :list, default['user']
      assert_match %r{quality: job 1}, result.stdout

      run_cron_on default, :remove, default['user']

      assert_raises Beaker::Host::CommandFailure do
        run_cron_on default, :list, default['user']
      end
    end

    step "#run_cron_on fails when removing cron jobs for an unknown user" do
      assert_raises Beaker::Host::CommandFailure do
        run_cron_on default, :remove, "nonexistentuser"
      end
    end

    step "#run_cron_on can list cron jobs for a user on all hosts when given a host array" do
      hosts.each do |host|
        # this basically requires us to add a cron entry to make this work
        run_cron_on host, :add, host['user'], "* * * * * /bin/ls >/dev/null"
      end

      results = run_cron_on hosts, :list, default['user']
      results.each do |result|
        assert_match %r{/bin/ls}, result.stdout
      end
    end

    step "#run_cron_on can add cron jobs for a user on all hosts when given a host array" do
      run_cron_on hosts, :add, default['user'], "* * * * * /bin/ls >/dev/null"

      results = run_cron_on hosts, :list, default['user']
      results.each do |result|
        assert_match %r{/bin/ls}, result.stdout
      end
    end

    step "#run_cron_on can remove cron jobs for a user on all hosts when given a host array" do
      run_cron_on hosts, :add, default['user'], "* * * * * /bin/ls >/dev/null"
      run_cron_on hosts, :remove, default['user']

      hosts.each do |host|
        assert_raises Beaker::Host::CommandFailure do
          run_cron_on host, :list, host['user']
        end
      end
    end
  end
end
