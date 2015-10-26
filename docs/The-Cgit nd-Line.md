* Using the gem

        $ beaker --log-level debug --hosts sample.cfg --tests test.rb

* Using latest git

        $ bundle exec beaker --log-level debug --hosts sample.cfg --tests test.rb

##Useful options
* `-h, --hosts FILE `, the hosts that you are going to be testing with
* `--log-level debug`, for providing verbose logging and full stacktraces on failure
* `--[no-]provision`, indicates if beaker should provision new boxes upon test execution. If `no` is selected then beaker will attempt to connect to the hosts as defined in `--hosts FILE` without first creating/running them through their hypervisors
* `--preserve-hosts [MODE]`, indicates what should be done with the testing boxes after tests are complete.  If `always` is selected then the boxes will be preserved and left running post-testing.  If `onfail` is selected then the boxes will be preserved only if tests fail, otherwise they will be shut down and destroyed.  If `never` is selected then the boxes will be shut down and destroyed no matter the testing results.
* `--parse-only`, read and parse all command line options, environment options and file options; report the parsed options and exit.

##The Rest
See all options with
* Using the gem

        $ beaker --help

* Using latest git

        $ bundle exec beaker --help
