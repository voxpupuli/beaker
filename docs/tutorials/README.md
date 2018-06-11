# Tutorials

This doc is here to help you get acquainted with beaker and how we run our acceptance tests at Puppet. We'll go over the purpose of each doc, giving you an idea of when you might need each one. The list has been organized as a learning guide for someone new to using beaker, so be aware of that if you're just dipping into a topic.

For more high level & motivation topics, checkout our [concepts docs](../concepts). If you're looking for more details on a topic than what is provided in the tutorials, checkout our [how to docs](../how_to). And if you'd like API level details, feel free to skip on over to our [Rubydocs](http://www.rubydoc.info/github/puppetlabs/beaker/frames). And without further pre-amble, we beaker!

## Installation

If you haven't installed beaker yet, your guide to doing so can be found [here](installation.md).

## Quick Start

As a completely new beaker user, the [quick start rake tasks doc](quick_start_rake_tasks.md) will take you through getting beaker running for the first time.

## OK, We're Running. Now What?

This is where things get interesting. There are a number of directions you can go, based on your needs. Here's a list of the common directions people take at this point.

### Test Writing

Most people reading this doc are in Quality orgs, or are developers who need to get some testing done for their current work. If getting a particular bit of testing done is your next step, this is the direction for you.

Checkout our [let's write a test](lets_write_a_test.md) to start with test writing!

### Running Beaker Itself

For the quick start guide, we resorted to using rake tasks to get beaker running quickly and easily. In the real world, people need much more customization out of their testing environments. One of the main ways people provide these options is through command line arguments.

If you want to find out more about running beaker itself, checkout [the command line](the_command_line.md).

### Environment Details

If you don't need to get your tests running _anywhere_, but need them on a ton of Operating Systems (OSes), then your next stop is setting up your test environment.

Our [creating a test environment doc](creating_a_test_environment.md) is the next spot for you!

### High Level Execution Details

For a higher level look at what happens during beaker execution, which we call a _run_, checkout our [test run doc](test_run.md). A _run_ is an entire beaker execution cycle, from when the command is run until beaker exits.

As one phase of a test run, the test suites are executed. To get more information about the test suites that are available, and how you configure them, you can check out our [test suites doc](test_suites.md).