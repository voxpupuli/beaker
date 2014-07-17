# How To Contribute To Beaker

## Getting Started

* If it is accessible to you, create a [Jira account](http://tickets.puppetlabs.com)
* Make sure you have a [GitHub account](https://github.com/signup/free)
* Submit a ticket for your issue, assuming one does not already exist.
  * Clearly describe the issue including steps to reproduce when it is a bug.
  * File in the appropriate location:
    * Using your [Jira account](http://tickets.puppetlabs.com)
      * Beaker bugs are submitted in the `QENG` project with the `Beaker` component.
    * As a [GitHub issue](https://github.com/puppetlabs/beaker/issues?direction=desc&sort=updated&state=open)
* Fork the [Beaker repository on GitHub](https://github.com/puppetlabs/beaker)

## Making Changes

* Create a topic branch from where you want to base your work.
  * This is the `master` branch in the case of Beaker
  * To quickly create a topic branch based on master use `git checkout -b my_contribution master`. Please avoid working directly on the `master` branch.
* Make commits of logical units.
* Check for unnecessary whitespace with `git diff --check` before committing.
* Make sure your commit messages are in the proper format. 

````
    (QENG-1234 OR gh-1234) Make the example in CONTRIBUTING imperative and concrete

    Without this patch applied the example commit message in the CONTRIBUTING
    document is not a concrete example.  This is a problem because the
    contributor is left to imagine what the commit message should look like
    based on a description rather than an example.  This patch fixes the
    problem by making the example concrete and imperative.

    The first line is a real life imperative statement with a ticket number
    from our issue tracker.  The body describes the behavior without the patch,
    why this is a problem, and how the patch fixes the problem when applied.
````
 
* Make sure you have added [RSpec](http://rspec.info/) tests that exercise your new code.  These test should be located in the appropriate `beaker/spec/` subdirectory.  The addition of new methods/classes or the addition of code paths to existing methods/classes requires additional RSpec coverage.
* Make sure that you have added documentation using [Yard](http://yardoc.org/), new methods/classes without apporpriate documentation will be rejected.
* Run the tests to assure nothing else was accidentally broken, using `rake test`
  * **Bonus**: if possible ensure that `rake test` runs without failures for additional Ruby versions (1.9, 1.8, 2.0). Beaker supports Ruby 1.8+, and breakage of support for older/newer rubies will cause a patch to be rejected.
* During the time that you are working on your patch the master Beaker branch may have changed - you'll want to [rebase](http://git-scm.com/book/en/Git-Branching-Rebasing) before you submit your PR with `git rebase master`.  A successful rebase ensures that your patch will cleanly merge into Beaker.
* Submitted patches will be smoke tested through a series of acceptance level tests that ensures basic Beaker functionality - the results of these tests will be evaluated by a Beaker team member.  Failures associated with the submitted patch will result in the patch being rejected.

## Making Trivial Changes

### Maintenance

For changes of a trivial nature, it is not always necessary to create a new ticket in Jira or GitHub. In this case, it is appropriate to start the first line of a commit with `(MAINT)` instead of a ticket/issue number. 

````
    (MAINT) Fix whitespace 

    - remove additional spaces that appear at EOL
````
### Version Bump For Gem Release

To prepare for a new gem release of Beaker the `version.rb` file is updated with the upcoming gem version number.  This is submitted with `(GEM)` instead of a ticket/issue number.

````
     (GEM) Update version for Beaker 1.16.1
````
### History File Update

To prepare for a new gem release of Beaker (after the version has been bumped) the `HISTORY.md` file is updated with the latest GitHub log.  This is submitted with `(HISTORY)` instead of a ticket/issue number.

````
    (HISTORY) Update history for release of Beaker 1.16.1
````
## Submitting Changes

* Sign the [Contributor License Agreement](http://links.puppetlabs.com/cla).
* Push your changes to a topic branch in your fork of the repository.
* Submit a pull request to [Beaker](https://github.com/puppetlabs/beaker)
* Update your ticket
  * Update your [Jira](http://tickets.puppetlabs.com) ticket to mark that you have submitted code and are ready for it to be reviewed (Status: Ready for Review).
    * Include a link to the pull request in the ticket.
  * Update your [GitHub issue](https://github.com/puppetlabs/beaker/issues?direction=desc&sort=updated&state=open)
    * Include a link to the pull request in the issue.
* PRs are reviewed as time permits.  

# Additional Resources

* [More information on contributing](http://links.puppetlabs.com/contribute-to-puppet)
* [Bug tracker (Jira)](http://tickets.puppetlabs.com)
* [Contributor License Agreement](http://links.puppetlabs.com/cla)
* [General GitHub documentation](http://help.github.com/)
* [GitHub pull request documentation](http://help.github.com/send-pull-requests/)
* Questions?  Comments?  Contact the Beaker team at the #puppet-dev IRC channel on freenode.org
  * The keyword `beaker` is monitored and we'll get back to you as quick as we can.
