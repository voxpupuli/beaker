step "Setup: Create remote test code tarballs"

FileUtils.rm Dir.glob("#{$work_dir}/dist/*.tgz") if Dir.glob("#{$work_dir}/dist/*.tgz")
system("cd #{$work_dir}/dist && tar czf ./ptest.tgz ptest/bin/* || echo tar cmd failed!; cd #{$work_dir}")
system("cd #{$work_dir}/dist && tar czf ./puppet.tgz etc/*      || echo tar cmd failed!; cd #{$work_dir}")

hosts.each do |host|
  unless File.file? "#{$work_dir}/dist/ptest.tgz"
    puts "ptest.tgz not found"
    fail_test "Sorry, ptest.tgz not found"
  end
  unless File.file? "#{$work_dir}/dist/puppet.tgz"
    puts "puppet.tgz not found"
    fail_test "Sorry, puppet.tgz not found"
  end

  step "Setup: SCP ptest tarball to host"
  scp_to host, "#{$work_dir}/dist/ptest.tgz", "/tmp"

  step "Setup: SCP puppet system test tarball Master"
  scp_to master, "#{$work_dir}/dist/puppet.tgz", "/tmp"

  step "Setup: untar ptest.tgz on host"
  on host,"tar xzf /tmp/ptest.tgz -C /"

  step "Untar puppet.tgz test code on master"
  on master," if [ -d /etc/puppetlabs ] ; then tar xzf /tmp/puppet.tgz -C / ; fi"

end
