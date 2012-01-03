test_name 'Ensure when used with a `-d` option the database is removed'

# NOTE: This file runs regardless of the option passed to the Uninstaller
# How we skip this test depends upon how we want to move it through Jenkins
# To Be Decided by Dom and Justin on 1/3/2012

# NOTE: we're use hard-coded usernames and passwords here!
step 'Ensure database is removed'
hosts.each do |host|
  next unless host['roles'].include? 'dashboard'

  # We should not be able to log into mysql with the PE created user
  on host, " ! mysql --user=console --password=puppet"

  # We should not be able to use the console db
  on host, " ! mysql --user=root --password=puppet -e 'use console'"

end

