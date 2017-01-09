test_name 'skip_test in with_puppet_running_on' do
  assert_raises SkipTest do
    with_puppet_running_on(master, {}) do
      skip_test 'skip rest'
      assert(false)
    end
  end
end

test_name 'pending_test in with_puppet_running_on' do
  assert_raises PendingTest do
    with_puppet_running_on(master, {}) do
      pending_test 'pending appendix prepended'
      assert(false)
    end
  end
end

test_name 'fail_test in with_puppet_running_on' do
  assert_raises FailTest do
    with_puppet_running_on(master, {}) do
      fail_test 'fail_test message'
      assert(false)
    end
  end
end
