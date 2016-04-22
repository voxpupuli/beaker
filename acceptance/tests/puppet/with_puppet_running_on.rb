test_name 'with_puppet_running_on' do

  with_puppet_running_on(master, {}) do
    puppet_service = master['puppetservice']
    on(master, puppet("resource service #{puppet_service}")).stdout do |result|
      assert_match(/running/,result,'did not find puppet service/master running')
    end
  end

end

test_name 'skip_test in with_puppet_running_on' do

  with_puppet_running_on(master, {}) do
    skip_test 'skip rest'
    assert(false)
  end

end

test_name 'pending_test in with_puppet_running_on' do

  with_puppet_running_on(master, {}) do
    pending_test 'pending appendix prepended'
    assert(false)
  end

end

# TODO: no idea how to test fail_test in here
