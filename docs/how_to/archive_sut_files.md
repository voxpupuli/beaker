# How to Archive Files from the Systems Under Test (SUTs)

Oftentimes when you're dealing with beaker test development or troubleshooting
a failed acceptance test, you'll need to get information from a SUT. The
traditional way that we've advocated getting information from these machines is
to use our [preserved hosts functionality](preserve_hosts.md).

If you're preserving hosts just to SSH in and look at log files, however, this
can be a tedious exercise. Why not just bring the log files to you on the
beaker coordinator? This doc explains exactly how to do that using our
`archive_file_from` Domain-Specific Language (DSL) method
([method rubydocs](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#archive_file_from-instance_method)).

# How Do I Use This?

`archive_file_from` is a part of the beaker DSL, so it's available in all test
suites. Just call it from your tests, and it'll execute, pulling any particular
file you need off your SUTs, and dropping it on your beaker coordinator's
file system.

A common example of a post-suite step to archive files that were created during
a particular test is included in the Rubydocs, referenced above. Path details,
and details of all method arguments are documented there as well. Check it out,
and with the right use, you won't need to preserve hosts at all to debug any
test failures.

# Challenges

## Conditionally Saving Files From SUTs

One thing that people tend to want from this functionality is to only archive
files from SUTs when a beaker run has failed. At this point, beaker does not
have access to other suites from a current one. This means that in practice,
a post-suite (where one would typically put archiving and other post-processes)
will not be able to archive files ONLY IF the test suite has had any failures
or errors.

Our suggestion to get the functionality required would be to have beaker always
archive the appropriate files in the post-suite of your tests, but then only
have Jenkins (or your job running system, whatever that may be) conditionally
take them from the beaker coordinator to whatever external archive system you
rely on for later analysis. This can both get you the files that you need from
the SUTs and save on space, as only files that need analysis will be kept.

# When Did This Come Out?

`archive_file_from` was originally added to the DSL in beaker
[2.48.0](https://github.com/puppetlabs/beaker/releases/tag/2.48.0), released on
[July 27, 2016](https://github.com/puppetlabs/beaker/blob/master/HISTORY.md#2480---27-jul-2016-47d3aa18).
