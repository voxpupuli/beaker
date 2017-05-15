# Beaker Test Runs

A Beaker test run consists of two primary phases: an SUT provision phase and a
suite execution phase. After suite execution, Beaker defaults to cleaning up and
destroying the SUTs. Leave SUTs running with the `--preserve-hosts` flag.


* **Provision**
  * Using supported hypervisors provision SUTs for testing on
  * Do any initial configuration to ensure that the SUTs can communicate with beaker and each other
  * skip with `--no-provision`
  * Provisioning also runs some basic setup on the SUTs
    * Validation
      * Check the SUTs for necessary packages (curl, ntpdate)
      * skip with `--no-validate`
    * Configuration
      * Do any post-provisioning configuration to the SUTs
      * skip with `--no-configure`


* **Execution**
  * Execute the files specified in each of the suites; for further documentation,
  please refer to [Test Suites & Failure Modes](test_suites.md)
