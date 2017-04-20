# Using Subcommands

**TODO** Better title?

## Why Subcommands?

## Available Subcommands

* `beaker init` - Initializes the required `.beaker/` configuration folder. This folder contains a `subcommand_options.yaml` file that is user-facing; altering this file will alter the options subcommand execution.
* `beaker provision` - Provisions hosts defined in your `subcommand_options file`. You can pass the `--hosts` flag here to override any hosts provided there.
* `beaker exec` - Run a single file, directory, or beaker suite. If supplied a file or directory, that resource will be run in the context of the`tests`suite; If supplied a beaker suite, then just that suite will run. If no resource is supplied, then this command executes the suites as they are defined in the configuration.
* `beaker destroy` - 

## Basic workflow

```
beaker init -h hosts_file -o options_file --keyfile ssh_key --pre-suite ./setup/pre-suit/my_presuite.rb
beaker provision
# Note: do not pass in hosts file, or use the '-t' flag! Just the file
# or directory. Do not pass GO. Do not collect $200.
beaker exec ./tests/my_test.rb
# Repeating the above command as needed
# When you're done testing using the VM that beaker provisioned
beaker destroy
```
