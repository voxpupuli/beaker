test_name "should not destroy a group that doesn't exist"

name = "test-group-#{Time.new.to_i}"

step "verify the group does not already exist"
run_puppet_on(agents, :resource, 'group', name, 'ensure=absent')

step "verify that we don't remove the group when it doesn't exist"
run_puppet_on(agents, :resource, 'group', name, 'ensure=absent') do
    fail_test "it looks like we tried to remove the group" if
        stdout.include? "notice: /Group[#{name}]/ensure: removed"
end

