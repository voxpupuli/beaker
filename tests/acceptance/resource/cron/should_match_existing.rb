test_name "cron resource should match existing"

tmpuser = "cron-test-#{Time.new.to_i}"
tmpfile = "/tmp/cron-test-#{Time.new.to_i}"

create_user = "user { '#{tmpuser}': ensure => present, managehome => false }"
delete_user = "user { '#{tmpuser}': ensure => absent,  managehome => false }"

agents.each do |host|
    step "ensure the user exist via puppet"
    apply_manifest_on host, create_user

    step "create the existing job by hand..."
    on host, "echo '* * * * * /bin/true' | crontab -u #{tmpuser} -"

    step "apply the resource on the host using puppet resource"
    run_puppet_on(host, :resource, "cron", "crontest", "user=#{tmpuser}",
                  "command=/bin/true", "ensure=present") do
        # REVISIT: This is ported from the original test, which seems to me a
        # weak test, but I don't want to improve it now.  --daniel 2010-12-23
        fail_test "didn't see the output we expected..." unless
            stdout.include? 'notice'
    end

    step "verify that crontab -l contains what you expected"
    on host, "crontab -l -u #{tmpuser}" do
        fail_test "didn't find the command as expected" unless
            stdout.include? "* * * * * /bin/true"
    end

    step "remove the crontab file for that user"
    on host, "crontab -r -u #{tmpuser}"

    step "remove the user from the system"
    apply_manifest_on host, delete_user
end
