# What is This?

Patterns for best-use solutions to (not so) common problems

## How do i set persistent environment variables on a SUT, such as PATH?
    host.add_env_var('PATH', '/opt/puppetlabs/bin:$PATH')

## How do i run commands on a SUT as a non-root user?
(warning) this should be abstracted into a beaker helper, or part of on():   BKR-168 - Beaker::DSL::Helpers needs "as" method READY FOR ENGINEERING

###create the user, then su with --command:
    on(host, puppet("resource user #{username} ensure=present managehome-true"))
    on(host, "su #{username} --command '#{command}'")
