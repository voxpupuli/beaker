# How To Upgrade from 3.y to 4.0

This is a guide detailing all the issues to be aware of, and to help people make any changes that you might need to move from beaker 2.y to 3.0. To test out beaker 4.0.0, we recommend implementing the strategy outlined [here](test_arbitrary_beaker_versions.md) to ensure this new major release does not break your existing testing.

## PE Dependency

In Beaker 3.0.0, `beaker-pe` was removed as a dependency. A mechanism to automatically include that module, if available, was added for convenience and to ease the transition. That shim has been removed. As of 4.0, you will have to explicitly require `beaker-pe` alongside `beaker` as a dependency in your project if you need it in your tests. You'll also need to add `require 'beaker-pe'` to any tests that use it.

## `PEDefaults` and `#configure_type_defaults_on`

PEDefaults has been moved to `beaker-pe`. The call to `#configure_type_defaults_on` that was previously made in `#set_env` is no longer made. You will now need to explicitly call `#configure_type_defaults_on` in your tests when needed.

## Puppet Dependency

Just like `beaker-pe` was removed as a dependency in 3.0, we have removed `beaker-puppet` as a dependency in 4.0. This means that you will have to explicitly require `beaker-puppet` alongside `beaker` as a dependency in your project if you need it in your tests. You'll also need to add `require 'beaker-puppet'` to any of your tests that use it.

## Hypervisor Loading

We have also removed the explicit dependency on all previously-included hypervisor libraries. Don't worry, the transition should be easy.

In order to use a specific hypervisor or DSL extension library in your project, you will need to include them alongside Beaker in your Gemfile or project.gemspec. E.g.

~~~ruby
# Gemfile
gem 'beaker', '~>4.0'
gem 'beaker-aws'
# project.gemspec
s.add_runtime_dependency 'beaker', '~>4.0'
s.add_runtime_dependency 'beaker-aws'
~~~

Beaker will automatically load the appropriate hypervisors for any given hosts file, so as long as your project dependencies are satisfied there's nothing else to do. No need to `require` this library in your tests. Simply specify `hypervisor: hypervisor_name` in your hosts file.

The following hypervisor libraries were removed in 4.0:

- [beaker-abs](github.com/puppetlabs/beaker-abs)
- [beaker-aws](github.com/puppetlabs/beaker-aws)
- [beaker-docker](github.com/puppetlabs/beaker-docker)
- [beaker-google](github.com/puppetlabs/beaker-google)
- [beaker-openstack](github.com/puppetlabs/beaker-openstack)
- [beaker-vagrant](github.com/puppetlabs/beaker-vagrant)
- [beaker-vcloud](github.com/puppetlabs/beaker-vcloud)
- [beaker-vmpooler](github.com/puppetlabs/beaker-vmpooler)
- [beaker-vmware](github.com/puppetlabs/beaker-vmware)

For acceptance testing, beaker-vmpooler, beaker-aws, and beaker-abs have been retained as development dependencies. These will be removed as the CI pipelines is upgraded, so *do not rely on them being there for your project*.