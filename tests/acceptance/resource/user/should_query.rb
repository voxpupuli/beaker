test_name "test that we can query and find a user that exists."

name = "test-user-#{Time.new.to_i}"

step "ensure that our test user exists"
run_puppet_on(agents, :resource, 'user', name, 'ensure=present')

step "query for the resource and verify it was found"
run_puppet_on(agents, :resource, 'user', name) do
    fail_test "didn't find the user #{name}" unless stdout.include? 'present'
end

step "clean up the user and group we added"
run_puppet_on(agents, :resource, 'user', name, 'ensure=absent')
run_puppet_on(agents, :resource, 'group', name, 'ensure=absent')
