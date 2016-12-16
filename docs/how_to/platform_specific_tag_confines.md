# Platform-Specific Tag Confines

## What Are These?

Typically when adding support for new platforms, a number of tests have to
be confined away from executing on that new platform. This can be for a
number of reasons, from partial implementation/support to tests having
incorrect assumptions that don't work on the new platform.

Platform-specific tag confines are structures created to make this workflow
easier, & achievable in a much more low-impact and adaptable way.

## Ok, So How Do We Use Them?

In the local options file (provided to the command line interface (CLI)
using the `--options-file` parameter), you can now provide an array of
hashes, where each hash specifies a platform to confine, based on the
tags included in the test. The local options file key is
`:platform_tag_confines`.

An example local options file is included 
below (remember that local options files have to be readable into
beaker as a ruby hash):

```ruby
{
  :platform_tag_confines => [
    {
      :platform => /^ubuntu-1404/,
      :tag_reason_hash => {
        "metrics" => "Can't do this, because bananas are in the field",
        "ui" => "TODO: We have not applied the UI tests to Ubuntu yet",
      }
    }, {
      :platform => /^centos-7/,
      :tag_reason_hash => {
        "database" => "WUT is this system doing? I dunno, must skip",
        "long_running" => "Flakiest test EVA. Would not run against centos-7, will kill...",
        "ui" => "CentOS reason",
      }
    }
  ]
}
```

In this case, there are two platform confines objects specified, one for
Ubuntu 14.04, and the other for CentOS 7. These objects consist of a hash,
filled with two entries: the `:platform` regex, and the `:tag_reason_hash`.

The `:platform` regex is just that, a Ruby regex matching the host's
platform string.

The `:tag_reason_hash` is another hash that maps tags to the reason that
tests that have this particular tag are being confined away from testing.

Taking one of our confine examples from above, we can think of the Ubuntu
UI confine example like this:

    "ui" tests will be confined away from ubuntu-1404 hosts, because
    "TODO: We have not applied the UI tests to Ubuntu yet"
    

## But Why Do We Need These?

Usually when we add platforms, the confining tests step is very heavy
handed & repetitive, usually consisting of adding boilerplate confine
calls that don't provide any explanation for why these are happening.
This can make it hard to later know the reason for the confine, making
it hard to know when we should be able to remove confines down the road.

This new workflow should provide a number of advantages over the previous
one, including:

1. Always reporting a reason for confining a platform
2. Allowing these to be dynamically determined from configuration, rather
    than needing to edit tens to hundreds of test files in-repo