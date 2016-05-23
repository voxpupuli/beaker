Beaker commands are executed through an ssh connection to each individual SUT.  Various options are supported during command execution that control how the commands themselves are executed, what output is generated and how results are interpreted.

## :acceptable_exit_codes

Provide either a single or an array of acceptable/passing exit codes for the provided command.  Defaults to the single exit code `0`.

    on host, puppet( 'agent -t' ), :acceptable_exit_codes => [0,1,2]

## :accept_all_exit_codes

Consider any exit codes returned by the command to be acceptable/passing.  Defaults to `nil`/`false`.

    on host, puppet( 'agent -t' ), :accept_all_exit_codes => true

## :expect_connection_failure

Assume that this command will cause a connection failure.  Used for `host.reboot` so that Beaker can handle the broken ssh connection.

    on host, "reboot", {:expect_connection_failure => true}

## :dry_run

Do not actually execute this command on the SUT.  Defaults to `false`.

    on host, "don't do this crazy thing", {:dry_run => true}

## :pty

Should this command be executed in a pseudoterminal?  Defaults to `false`.

    on host, "sudo su -c \"service ssh restart\"", {:pty => true})

## :silent

Do not output any logging for this command.  Defaults to `false`.

    on host, "echo hello", {:silent => true}

## :stdin

Specifies standard input to be provided to the command post execution.  Defaults to `nil`.

    on host, "this command takes input", {:stdin => "hiya"}

## [:run_in_parallel](runner/run_in_parallel.md)

Execute the command against all hosts in parallel

    on hosts, puppet( 'agent -t' ), :run_in_parallel => true
