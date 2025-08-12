test_name 'confirm unix-specific package methods work'
confine :except, :platform => %w(windows osx)

step '#update_apt_if_needed : can execute without raising an error'
hosts.each do |host|
  host.update_apt_if_needed
end
