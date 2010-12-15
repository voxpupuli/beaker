# Ported from a collection of small spec tests in acceptance.
#
# Unified into a single file because they are literally one-line tests!

test_name "Trivial puppet tests"

step "check that puppet apply displays notices"
run_manifest(agents, "notice 'Hello World'") do
  exit_code == 0 or fail_test("exit with non-zero return code")
  stdout =~ /notice:.*Hello World/ or fail_test("missing notice!")
end

step "verify help displays something for puppet master"
puppet(agents, :master, "--help") do
  exit_code == 0 or fail_test("exit with non-zero return code")
  stdout =~ /puppet master/ or fail_test("improper help output")
end
