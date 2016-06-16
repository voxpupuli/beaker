Beaker is an acceptance testing harness for Puppet PE and other Puppet Projects.  It can also be used as a virtual machine provisioner - setting up machines, running any configuration on those machines and then exiting.  

Beaker goes through several phases when running tests

* Provisioning
  * skip with `--no-provision`
  * Using supported hypervisors provision SUTs for testing on
  * Do any initial configuration to ensure that the SUTs can communicate with beaker and each other
* Validation
  * skip with `--no-validate`
  * Check the SUTs for necessary packages (curl, ntpdate)
* Configuration
  * skip with `--no-configure`
  * Do any post-provisioning configuration to the test nodes
* Testing
   For test running options, please refer to [Beaker Test Run Options] (test_suites.md)
* Reverting
  * Skip with `--preserve-hosts`
  * Destroy and cleanup all SUTs
* Cleanup
  * Report test results

Beaker runs tests written in Ruby with an additional DSL API.  This gives you access to all standard Ruby along with acceptance testing specific commands.
