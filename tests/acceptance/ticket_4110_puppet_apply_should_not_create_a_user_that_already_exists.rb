test_name "#4110: puppet apply should not create a user that already exists"

run_manifest(agents, "user { 'root': ensure => 'present' }") do
  exit_code == 0 or fail_test("non-zero exit code")
  fail_test("we tried to create root on this host") if stdout =~ /created/
end
