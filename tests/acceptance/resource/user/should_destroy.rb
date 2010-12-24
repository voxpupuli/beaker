test_name "verify that puppet resource correctly destroys users"

user  = "test-user-#{Time.new.to_i}"
group = user

step "ensure that the user and associated group exist"
run_puppet_on(agents, :resource, 'group', group, 'ensure=present')
run_puppet_on(agents, :resource, 'user', user, 'ensure=present', "gid=#{group}")

step "try and delete the user"
run_puppet_on(agents, :resource, 'user', user, 'ensure=absent')

step "verify that the user is no longer present"
on(agents, "getent passwd #{user}", :acceptable_exit_codes => [2]) do
    fail_test "found the user in the output" if stdout.include? "#{user}:"
end

step "remove the group as well..."
run_puppet_on(agents, :resource, 'group', group, 'ensure=absent')
