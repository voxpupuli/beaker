# Testing Beaker Itself

While Beaker provides the testing harness for much of the acceptance testing that happens at Puppet, Beaker itself must also go through a testing process for changes submitted to itself to ensure that releases of Beaker do not break pipelines, jobs, and tests that rely on it. This document describes what is actually covered in Beaker's own testing and how that testing is accomplished.

## Testing Coverage

### Product Coverage

Beaker test coverage covers the LTS PE version, currently 2016.4.0, and the latest released version of PE, currently 2016.5.0. Since there is only a single major version of Puppet itself currently supported, beaker only run tests on the latest y-release of Puppet 4, currently 4.8.z. This currently resolves to puppet-agent 1.8.x.

### Platform Coverage

The platforms that beaker covers in its regression testing are largely what is supported by either Puppet or Puppet Enterprise. All variants that are supported by Puppet Enterprise as master platforms are tested. Variants that are agent only are more sparsely covered, generally testing the latest released version.

## Test Suite Phases

### Beaker Spec

The initial step in Beaker's pipeline is to execute spec testing with supported and future rubies; 2.2.5 and 2.3.1.

### Beaker Acceptance

All acceptance tests use actual OS's with beaker installed and use beaker itself to verify that its own methods and classes are working.

* The Base tests are tests that do not require puppet be installed on the SUT. This includes much of the DSL and host helpers.
* The puppet tests rely on puppet being installed in the pre-suite

### Beaker Regression

The Beaker regression tests are an ever evolving set of Jenkins jobs that use acceptance jobs defined in other pipelines with the Beaker PR changes. We run these jobs to ensure the PR changes do not cause breakage in existing acceptance jobs. The tests themselves are maintained by each separate team.
