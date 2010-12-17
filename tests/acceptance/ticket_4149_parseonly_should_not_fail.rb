test_name "#4149: parseonly should do the right thing"

step "test with a manifest with syntax errors"
manifest = 'class someclass { notify { "hello, world" } }'
run_manifest(agents, manifest, '--parseonly', :rc => 1) {
  stdout =~ /Could not parse for .*: Syntax error/ or
    fail_test("didn't get a reported systax error")
}

step "test with a manifest with correct syntax"
manifest = 'class someclass { notify("hello, world") }'
run_manifest(agents, manifest, '--parseonly')

# REVISIT: This tests the current behaviour, which is IMO not actually the
# correct behaviour.  On the other hand, if we change this we might
# unexpectedly break things out in the wild, so better to be warned than to be
# surprised by it.
step "test with a class with an invalid attribute"
manifest = 'file { "/tmp/whatever": fooble => 1 }'
run_manifest(agents, manifest, '--parseonly')
