## So What Are Types Anyway?

Historically, Puppet Open Source and Enterprise have had different paths for different resources.  Beaker supports these configurations through the use of its `type` parameter.  The Beaker CLI exposes this parameter with the `--type` option.  

The two older types are represented by the `foss` and `pe` values.

Note that if you don't provide any type, the default is [pe](https://github.com/puppetlabs/beaker/blob/master/lib/beaker/options/presets.rb#L131).

## New With Puppet 4: The AIO Type!

With the introduction of the All-In-One (AIO) Agent in Puppet 4, the paths have been unified across both versions (Open Source & Enterprise).  In order to support this, Beaker has added the `aio` type.

Passing this argument will setup the machines to use the new AIO pathing.  This should be all you need to be correctly setup to use the AIO Agent in Puppet 4 and beyond!
