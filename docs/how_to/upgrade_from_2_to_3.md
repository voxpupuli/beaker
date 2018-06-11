# How To Upgrade from 2.y to 3.0

This is a guide detailing all the issues to be aware of, and to help people make any changes that you might need to move from beaker 2.y to 3.0. To test out beaker 3.0.0, we recommend implementing the strategy outlined [here](test_arbitrary_beaker_versions.md) to ensure this new major release does not break your existing testing.

## Ruby version 1.9.3 no longer supported

Official support for 1.9.3 has been eol'd since Feb 2015; the beaker 3.0.0 release drops support for ruby 1.9.3 and will not install with ruby 1.9.3. We suggest using ruby >= 2.2.5, as that is the version we currently test and support at Puppet.

## Locally Cached Files

This is a change of the `:cache_files_locally` preset from `true` to `false`.

At this time, the `:cache_files_locally` setting only affects the [`fetch_http_file` method](https://github.com/puppetlabs/beaker/blob/master/lib/beaker/dsl/helpers/web_helpers.rb#L44). This is an internal method used in both Puppet Enterprise (PE) and Open Source Puppet install helpers to download files from the internet to the Beaker coordinator.

If a file with the same destination name already exists on the coordinator, Beaker would not fetch the file and use the cached copy instead. In general, this wasn't a big problem because we typically have our version numbers in our install artifacts, so file name matching is enough. In our Windows MSI installers, however, we would many times not have versions built into the file name. Since that's the case, you could get an old version installed because it was already on your coordinator filesystem. The `:cache_files_locally` setting allows you to set whether you want to use a local file cache, or get fresh installers every time. This setting is now set to false, and will get installers from the online source every time.

If you'd like to keep this setting the way it was in 2.y, then just set the global option `:cache_files_locally` to `false`. Checkout the [Argument Processing and Precedence](../concepts/argument_processing_and_precedence.md) doc for info on how to do this.

## EPEL package update

In beaker < 3.0.0, the epel package names had hardcoded defaults listed in the presets default; in beaker >= 3.0.0, beaker utilizes the `release-latest` file provided on epel mirrors for el versions 5, 6, and 7. Since only the latest epel packages are available on epel mirrors, beaker only supports installation of that latest version.

## Solaris and AIX Hypervisors removed

Special cased hypervisor support for Solaris and AIX have been removed in favor of a `hypervisor=none` workflow where the provisioning of SUTs is handled separately outside of beaker itself. Solaris and AIX are still of course supported as `platform` strings; only these special-cased hypervisors have been removed.

## Environment Variable DSL Methods

In [BKR-914](https://tickets.puppetlabs.com/browse/BKR-914) we fixed our host methods that deal with environment variables ( [#add_env_var](http://www.rubydoc.info/github/puppetlabs/beaker/Unix/Exec#add_env_var-instance_method), [#get_env_var](http://www.rubydoc.info/github/puppetlabs/beaker/Unix/Exec#get_env_var-instance_method), and [#clear_env_var](http://www.rubydoc.info/github/puppetlabs/beaker/Unix/Exec#clear_env_var-instance_method)).

Before, these methods used regular expressions that were too loose. This means that in an example of a call like `get_env_var('abc')`, the environment variables `abc=123`, `xx_abc_xx=123`, and `123=abc` would all be matched, where the intent is to get `abc=123` alone. From Beaker 3.0 forward, this will be the case.

## beaker-pe Import Changes

Starting in beaker 3.0, there is no explicit beaker-pe requirement in beaker. This separates the two, meaning that you'll have to explicitly require beaker-pe if you do need it in your testing. And if you don't need it, you won't get it, limiting your dependencies & exposure to unnecessary code.

Luckily, if you do need it, this shouldn't be hard to update. These are the steps needed to use beaker-pe with beaker 3.0:

1. put a dependency on beaker-pe in your Gemfile as a sibling to your beaker
  requirement (make sure beaker-pe is >= 1.0)
2. That's it! Beaker itself will still `require 'beaker-pe'`, so making sure that it is specified
  in your project's Gemfile is the only code change you will need to make. Please note that this
  is only supported with the `beaker-pe` gem; other beaker libraries will need an explicit `require`
  in your test setup.
