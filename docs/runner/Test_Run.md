## Running Beaker Tests

Beaker goes through several phases when running tests. All phases are not mandatory and can be skipped using “skip with” options. The various phases and the corresponding skip options are as follows:

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
  For test configurations, please refer to [Beaker Test Suites] (test_suites.md)
* Reverting
  * Skip with `--preserve-hosts`
  * Destroy and cleanup all SUTs
* Cleanup
  * Report test results