# How To Install Puppet

This doc will guide you through the process of installing Puppet Agent using beaker's DSL helpers.

Note that this is not a complete documentation of the process, but a general overview. There will be specific hiccups for particular platforms and special cases. These are not all included at this point. The idea is that as we come upon them, we will now have a place to document those details, so that we can over time bring this to 100% completeness.

As of Beaker 4.0, these DSL extensions have been moved to `beaker-puppet`, so you'll need to add that gem in your project and require it in your test cases.

# First Things First: What Do You Want to Install?

If you understand [beaker's roles](https://github.com/puppetlabs/beaker/blob/master/docs/concepts/roles_what_are_they.md) and just want the shortcuts to installing Open Source Puppet across your testing environment, then you should go to our "High Level Shortcuts" section below.

If you'd like to only install Puppet Agents, please checkout our "Puppet Agent Installs" section for more information.

# High Level Shortcuts

The [`install_puppet_on`](http://www.rubydoc.info/gems/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_puppet_on-instance_method) method is a wrapper on our installing Puppet behavior that allows you to pass in which hosts in particular you'd like to install Puppet on as well as specifying the options used yourself. Please checkout the Rubydocs linked above for more info on this method.

The [`install_puppet`](http://www.rubydoc.info/gems/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_puppet-instance_method) is deprecated. It's a shortcut method that just calls `install_puppet_on` passing the entire hosts array and global options hash. You can get the same using this code in your pre-suite:

```ruby
install_puppet_on(hosts, options)
```

Note that both of the high level methods will call the `install_puppet_agent_on` method to install released Puppet Agent versions for your agent Systems Under Test (SUTs). Please checkout our "Released Open Source Puppet Agents" section below for more information on this method.

# Puppet Agent Installs

There are a number of Puppet Agents that you could be installing. There aren't only an ever-growing number of versions, but you can get Puppet Agent from a number of locations.

If you'd like to install the Puppet Agent that comes with your particular Puppet Enterprise (PE) install, then please skip to our "PE Promoted Agent Installs" section below.

For our different Open Source variants, check out the sections just below, which differentiate between released & development Puppet Agent versions.

### Released Open Source Puppet Agents

To install a released version of Puppet Agent, beaker provides the [`install_puppet_agent_on`](http://www.rubydoc.info/gems/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_puppet_agent_on-instance_method) method. Please checkout the Rubydocs for more info on this method.

### Development Open Source Puppet Agents

To install a development build of Puppet Agent, beaker provides the [`install_puppet_agent_dev_repo_on`](http://www.rubydoc.info/gems/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_puppet_agent_dev_repo_on-instance_method) method. Please checkout the Rubydocs for more info on this method.

### PE Promoted Agent Installs

If you're using this method, then you're going to be downloading the installer from a URL configured like so:

```ruby
http://pm.puppetlabs.com/puppet-agent/#{ pe_version }/#{ puppet_agent_version }/repos
```

`pe_version` is a variable that you can provide using either the host or global property `:pe_ver`. This is usually done in the hosts file, and will default to `4.0.0-rc1` if nothing is specified.

`puppet_agent_version` is a variable you can provide the value of through the same methods as `pe_version` above. It will default to `latest`.

Beaker's DSL method to install from this location is [`install_puppet_agent_pe_promoted_repo_on`](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_puppet_agent_pe_promoted_repo_on-instance_method). Follow the link to get API-level docs on this method for more info.