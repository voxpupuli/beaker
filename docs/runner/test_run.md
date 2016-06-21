# Beaker Test Runs  

A Beaker run typically has the following phases. All the phases are not mandatory. Each phase provides an option to skip.  

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
  * For test running options, please refer to [Test Suites & Failure Modes](test_suites.md)


* Reverting
  * Skip with `--preserve-hosts`
  * Destroy and cleanup all SUTs


* Cleanup
  * Report test results