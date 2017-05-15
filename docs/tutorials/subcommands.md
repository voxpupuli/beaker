# Using Subcommands

The document gives an overview of the subcommands that Beaker supports and
describes how to use them.

## Why Subcommands?

Subcommands are designed to make test development and iteration simpler by
separating out all of the phases of a Beaker [test run](test_run.md)*. Instead
of requiring the entirety of your Beaker execution in one command, subcommands
allow you to execute each phase independently. This allows for faster feedback
for potential failures and better control for iterating over actual test
development.

Most subcommands pass through flags to the Beaker options. For instance, you can
pass through `--hosts` to the `init` subcommand and it will parse the `--hosts`
argument as if you were executing a Beaker run*. Please review the
subcommand specific help for further information. You can see the help for a
specific subcommand by running `beaker help SUBCOMMAND`.

*Please note that in this document, a Beaker `run` is standard beaker invocation
without any subcommands.
## Available Subcommands

### beaker init
Initializes the required `.beaker/` configuration folder. This folder contains a
`subcommand_options.yaml` file that is user-facing; altering this file will
alter the options for subcommand execution.

### beaker provision
Provisions hosts defined in your `subcommand_options file`. You can pass the
`--hosts` flag here to override any hosts provided there.

### beaker exec
Run a single file, directory, or Beaker suite. If supplied a file or directory,
that resource will be run in the context of the `tests` suite; if supplied a
Beaker suite, then just that suite will run. If no resource is supplied, then
this command executes the suites as they are defined in the configuration in the
`subcommand_options.yaml`.

### beaker destroy
Execute this command to deprovision your systems under test(SUTs).

## Basic workflow

```
beaker init -h hosts_file -o options_file --keyfile ssh_key --pre-suite ./setup/pre-suit/my_presuite.rb
beaker provision
# Note: do not pass in hosts file, or use the '-t' flag! Just the file
# or directory. Do not pass GO. Do not collect $200.
beaker exec ./tests/my_test.rb
# Repeating the above command as needed
# When you're done testing using the VM that Beaker provisioned
beaker destroy
```
