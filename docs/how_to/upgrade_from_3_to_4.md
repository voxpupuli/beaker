# How To Upgrade from 3.y to 4.0

This is a guide detailing all the issues to be aware of, and to help people make any changes that you might need to move from beaker 2.y to 3.0. To test out beaker 4.0.0, we recommend implementing the strategy outlined [here](test_arbitrary_beaker_versions.md) to ensure this new major release does not break your existing testing.

## PE Dependency

In Beaker 3.0.0, `beaker-pe` was removed as a dependency. A mechanism to automatically include that module, if available, was added for convenience and to ease the transition. That shim has been removed. As of 4.0, you will have to explicitly require `beaker-pe` alongside `beaker` as a dependency in your project if you need it in your tests. You'll also need to add `require 'beaker-pe'` to any tests that use it.

# `PEDefaults` and `#configure_type_defaults_on`

PEDefaults has been moved to `beaker-pe`. The call to `#configure_type_defaults_on` that was previously made in `#set_env` is no longer made. You will now need to explicitly call `#configure_type_defaults_on` in your tests when needed.
