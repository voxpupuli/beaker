##The Task

Consider if mcollectived incorrectly spawned a new process with every puppet agent run on Ubuntu 10.04.  We need an acceptance test to check that a new process is not spawned and to ensure that this issue does not regress in new builds.

##Figure Out Test Steps

What needs to happen in this test:

* Install PE
* Restart mcollective twice
* Check to see if more than one mcollective process is running

##Create a host configuration file
    $ beaker-hostgenerator redhat7-64ma > redhat7-64ma.yaml

##Install PE

We prefer to install PE once and then run a set of tests, so PE installation should not be part of the actual acceptance test.

    $ mkdir setup
    $ cd setup
    $ cat > install.rb << RUBY
    test_name "Installing Puppet Enterprise" do
    install_pe
    RUBY
    $ cd ..

This places our install steps in a ruby script (install.rb) which will run on localhost, but the #install_pe method knows where to install puppet enterprise based on the host configuration in use.
The install.rb script is used in our commandline to beaker, below.

## Create a test file

We need to create a test file to run.

### Define some test commands to run
####Restart mcollective twice

Here's our magic command that restarts mcollective:

    restart_command = "bash -c '[[ -x /etc/init.d/pe-mcollective ]] && /etc/init.d/pe-mcollective restart'"

####Check to see if more than one mcollective process is running

Here's our magic command that throws an error if more than one mcollective process is running:

    process_count_check = "bash -c '[[ $(ps auxww | grep [m]collectived | wc -l) -eq 1 ]]'"

###Put it all together

Here's the finished acceptance test.

```ruby
test_name "/etc/init.d/pe-mcollective restart check"

# Don't run these tests on the following platforms
confine :except, :platform => 'solaris'
confine :except, :platform => 'windows'
confine :except, :platform => 'aix'

step "Make sure the service restarts properly"
hosts.each do |host|
  # Commands to execute on the target system.
  restart_command = "bash -c '[[ -x /etc/init.d/pe-mcollective ]] && /etc/init.d/pe-mcollective restart'"
  process_count_check = "bash -c '[[ $(ps auxww | grep [m]collectived | wc -l) -eq 1 ]]'"

  # Restart once
  on(host, restart_command) { assert_equal(0, exit_code) }
  # Restart again
  on(host, restart_command) { assert_equal(0, exit_code) }
  # Check to make sure only one process is running
  on(host, process_count_check) { assert_equal(0, exit_code) }
end
```

## Run it!
You can now run this with

    beaker --host redhat7-64ma.yaml --pre-suite install.rb --test mytest.rb

Next up you may want to look at the [Beaker test for a module](../how_to/write_a_beaker_test_for_a_module.md) page.
