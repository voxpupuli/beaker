# hosts should be able to talk to each other by name
step "hosts can ping each other"
hosts.each do |one|
  hosts.each do |two|
    assert_equal(one.ping(two), true)
  end
end
