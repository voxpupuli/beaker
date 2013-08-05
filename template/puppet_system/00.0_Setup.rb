step "Setup: Create remote test code tarballs"

FileUtils.rm Dir.glob("dist/*.tgz") if Dir.glob("dist/*.tgz")
system("cd dist && tar czf ./ptest.tgz ptest/bin/* || echo tar cmd failed")
system("cd dist && tar czf ./puppet.tgz etc/*      || echo tar cmd failed")

hosts.each do |host|
  unless File.file? "dist/ptest.tgz"
    fail_test "Sorry, ptest.tgz not found"
  end
  unless File.file? "dist/puppet.tgz"
    fail_test "Sorry, puppet.tgz not found"
  end

  step "Setup: SCP ptest tarball to host"
  scp_to host, "dist/ptest.tgz", "/tmp"

  step "Setup: SCP puppet system test tarball Master"
  scp_to master, "dist/puppet.tgz", "/tmp"

  step "Setup: untar ptest.tgz on host"
  on host,"tar xzf /tmp/ptest.tgz -C /"

  step "Untar puppet.tgz test code on master"
  on master," if [ -d /etc/puppetlabs ] ; then tar xzf /tmp/puppet.tgz -C / ; fi"

end
