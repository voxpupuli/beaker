# Test Suites & Failure Modes

Beaker test suites correspond to test suites in most testing frameworks,
being containers for tests or pre- or post-testing files to execute.

There are two main ways that you specify which test suites a particular
file belongs in. The first way is to use the Beaker command line interface
(CLI) arguments. These are specified in runtime order below:

    --pre-suite
    —-tests
    —-post-suite
    —-pre-cleanup

If you’d like to find out more information about these arguments, or how
exactly you pass the specified files to each suite, execute `beaker —-help`
at the CLI.

The second way is to provide suite arguments through config files. There
are two places that you can provide this info:

1. The `CONFIG` section of a hosts file.
2. A local options file passed through the `--options-file` CLI argument.

Either way, the keys for the arguments needed are listed below, respective
to the arguments listed above:

    :pre_suite
    :tests
    :post_suite
    :pre_cleanup

*Note* that one difference between the two methods is that if you provide the
options via the CLI, we support various input methods such as specifying
individual files vs paths to folders. The second option (providing keys to
config files) only works if each file is fully specified. Beaker will not
find all files in a directory in the second case, that expansion is only done
on the CLI inputs.

# Suite Details, & Failure Mode Behavior

This section is to explain the particulars of any suite, and any warnings or
notes about using them, including how they behave in Beaker’s different
failure modes.

## Pre-Suite

The pre-suite is for setting up the Systems Under Test (SUTs) for the testing
suite. No surprises here, usually these files are filled with the setup and
installation code needed to verify that the operating assumptions of the 
software being tested are true.

Pre-suites, since they’re supposed to contain just setup code, will fail-fast
and the entire Beaker run will be abandoned if setup fails, since testing
assumes that setup has succeeded.

## Tests

Time to actually test! This suite contains the test files that you would
like to verify new code with.

The test suite behaves according to the global fail-mode setting.

## Post-Suite

Usually the post-suite is used to clean up any fixtures that your tests might
have poisoned, collect any log files that you’d like to later review, and
to get any resources from the SUTs before they are cleaned up / deleted.

The post-suite only runs if the fail-mode is set to slow, which it is by
default. Fast fail-mode will skip this suite, so that you can get feedback
quicker, and you can potentially check out the system in the state exactly
that it failed in.

## Pre-cleanup

The pre-cleanup suite is for tasks that you’d like to run at the end of your
tests, regardless of Beaker’s fail-mode. You can think of this behaving as a
`finally` block at the end of a `try-rescue` one.

The pre-cleanup suite falls back to the global fail-mode setting, which
defaults to slow, meaning it will run all tests regardless of any early
failures.
