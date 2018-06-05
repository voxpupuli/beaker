# Rake test tasks for running beaker

There are some rake tasks that you can use to run Beaker tests from your local project dir.

To use them from within your own project, you will need to require the following file in your project's rakefile:

    require 'beaker/tasks/test'

You will also need to have Beaker installed as part of your bundle.

When you run:

    rake --tasks

from your project dir, you should see (as well as any rake tasks you have defined locally)

    rake beaker:test[hosts,type]  # Run Beaker Acceptance
    rake beaker:test:git[hosts]   # Run Beaker Git tests
    rake beaker:test:pe[hosts]    # Run Beaker PE tests

The last two tasks assume that you have an options file in `/acceptance` named `beaker-git.cfg` and `beaker-pe.cfg` respectively.

Your options file would look something like:

    {
      :type            => 'git',
      :pre_suite       => ['./acceptance/setup/install.rb'],
      :hosts_file      => './acceptance/config/windows-2012r2-x86_64.cfg',
      :log_level       => 'debug',
      :tests           => ['./acceptance/tests/access_rights_directory', './acceptance/tests/identity',
                            './acceptance/tests/owner', './acceptance/tests/propagation',
                            './acceptance/tests/use_cases', './acceptance/tests/access_rights_file', './acceptance/tests/group',
                            './acceptance/tests/inheritance', './acceptance/tests/parameter_target', './acceptance/tests/purge'],
      :keyfile         => '~/.ssh/id_rsa-acceptance',
      :timeout         => 6000
    }

To use the more generic test task, you will need to pass in the type as the 2nd argument to the rake task:

    rake beaker:test[,smoke]

This will assume that you have created the file:

    acceptance/beaker-smoke.cfg

