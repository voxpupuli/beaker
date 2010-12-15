test_name "#4059: ralsh can change settings"

target = "/tmp/hosts-#4059"

on agents, "rm -f #{target}"
puppet(agents, :resource,
       "host example.com ensure=present ip=127.0.0.1 target=#{target}") do
  exit_code == 0 or fail_test("darn, exit code is terribly wrong")

  stdout.index('Host[example.com]/ensure: created') or
    fail_test("missing notice about host record creation")
end
on(agents, "cat #{target}") do
  stdout =~ /^127\.0\.0\.1\s+example\.com/ or
    fail_test("missing host record in #{target}")
end

on agents, "rm -f #{target}"
