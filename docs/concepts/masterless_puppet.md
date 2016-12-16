# Overview

## What is masterless Puppet?

Masterless Puppet is a common way of running Puppet where you might have a number of Puppet Agents, but no hosts running under any other roles (master, dashboard, database, default).

## Why Would You Want to Do This?

A few examples of common situations where running masterless Puppet would be useful are below:

- Testing modules against Windows.  Traditionally, a non-Windows master would be required, but is really just needless overhead in this case.
- running Puppet to provision hosts, only running it the once, using `puppet agent`, and then providing it to your users

## How Do I Run Masterless?

In order to have Beaker support a masterless Puppet setup, you have to do a few things:

1. include the `masterless: true` flag in the `CONFIG` section of your hosts file
2. Make sure the roles are correct for the hosts now. You'll want to make sure a host doesn't have a role that it won't be able to fulfill
3. Run Beaker just like you normally would

# Under the Hood

## What is Beaker Doing by Default?

Be default (without the masterless flag), when someone calls for a host of a particular role, using the `Beaker::DSL::Roles` module's methods (ie. `master`, `dashboard`, etc), Beaker checks to verify that a host was given with that role.

If no host was given with this role, then Beaker throws a `DSL::Outcomes::FailTest` Error, which causes that test case to fail.

## What Does This Flag Do?

Inside Beaker, when you call `Beaker::DSL::Roles` module's methods with the masterless flag set, Beaker will allow there to be hosts which don't fit defined roles.  If a host can't be found for a particular role, that role method will now return `nil`.

If you'd like to test both masterless and not, you'll have to deal with a role method potentially returning `nil`.

## How Do I Avoid Issues With This?

You can make it so that a test will only run if we're not running masterless with this line:

    confine :to, :masterless => false

and vice versa.
