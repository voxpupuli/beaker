test_name "#4149: parseonly should do the right thing"

step "test with a manifest with syntax errors"
manifest = 'class someclass { notify { "hello, world" } }'
run_manifest(agents, manifest, '--parseonly') {
  exit_code == 1 or fail_test("expected rc 1, but didn't get it")
  stdout =~ /Could not parse for .*: Syntax error/ or
    fail_test("didn't get a reported systax error")
}

step "test with a manifest with correct syntax"
manifest = 'class someclass { notify("hello, world") }'
run_manifest(agents, manifest, '--parseonly')

step "test with a class with an invalid attribute"
manifest = 'file { "/tmp/whatever": fooble => 1 }'
run_manifest(agents, manifest, '--parseonly') {
  # REVISIT: This tests the current behaviour, which is IMO not actually the
  # correct behaviour.  Perhaps this should be flagged as "TODO" rather than
  # as a test asserting nothing changes.
  exit_code == 0 or fail_test("incorrect exit code")
}
