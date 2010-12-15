test_name "#3172: puppet kick with hostnames on the command line"
step "verify that we trigger our host"

target = 'working.example.org'
puppet(agents, :kick, target) do
  # Not checking exit code, because this is technically an error situation.
  fail_test "didn't trigger #{target}" unless stdout.index "Triggering #{target}"
end
