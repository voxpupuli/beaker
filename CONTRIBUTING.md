# How To Contribute To Beaker

## Getting Started

* Create a [Jira account](http://tickets.puppetlabs.com)
* Make sure you have a [GitHub account](https://github.com/signup/free)
* Submit a ticket for your issue, assuming one does not already exist.
  * Clearly describe the issue including steps to reproduce when it is a bug.
  * File a ticket in the [BKR project](https://tickets.puppetlabs.com/issues/?jql=project%20%3D%20BKR)
* Fork the [Beaker repository on GitHub](https://github.com/puppetlabs/beaker)

## Making Changes

* Create a topic branch from your fork of [puppetlabs/beaker](https://github.com/puppetlabs/beaker). 
  * Please title the branch after the beaker ticket you intend to address, ie `BKR-1234`.
* Make commits of logical units.
* Check for unnecessary whitespace with `git diff --check` before committing.
* Make sure your commit messages are in the proper format.

````
    (BKR-1234) Make the example in CONTRIBUTING imperative and concrete

    Without this patch applied the example commit message in the CONTRIBUTING
    document is not a concrete example.  This is a problem because the
    contributor is left to imagine what the commit message should look like
    based on a description rather than an example.  This patch fixes the
    problem by making the example concrete and imperative.

    The first line is a real life imperative statement with a ticket number
    from our issue tracker.  The body describes the behavior without the patch,
    why this is a problem, and how the patch fixes the problem when applied.
````

* During the time that you are working on your patch the master Beaker branch may have changed - you'll want to [rebase](http://git-scm.com/book/en/Git-Branching-Rebasing) on top of [Beaker's](https://github.com/puppetlabs/beaker) master branch before you submit your PR.  A successful rebase ensures that your PR will cleanly merge into Beaker.

### Testing

* Submitted PR's will be tested in a series of spec and acceptance level tests - the results of these tests will be evaluated by a Beaker team member, as test results are currently not accessible by the public. Testing failures that require code changes will be communicated in the PR discussion.
* Make sure you have added [RSpec](http://rspec.info/) tests that exercise your new code.  These test should be located in the appropriate `beaker/spec/` subdirectory.  The addition of new methods/classes or the addition of code paths to existing methods/classes requires additional RSpec coverage.
  * Beaker uses RSpec 3.1.0+, and you should **NOT USE** deprecated `should`/`stub` methods - **USE** `expect`/`allow`. See a nice blog post from 2013 on [RSpec's new message expectation syntax](http://teaisaweso.me/blog/2013/05/27/rspecs-new-message-expectation-syntax/).
  * Run the tests to assure nothing else was accidentally broken, using `rake test`
    * **Bonus**: if possible ensure that `rake test` runs without failures for additional Rubies (versions 1.9.3 and above).

### Documentation

* Make sure that you have added documentation using [Yard](http://yardoc.org/) as necessary for any new code introduced.
* More user friendly documentation will be required for PRs unless exempted. Documentation lives in the [docs/ folder](docs).

## Making Trivial Changes

### Maintenance

For changes of a trivial nature, it is not always necessary to create a new ticket in Jira. In this case, it is appropriate to start the first line of a commit with `(MAINT)` instead of a ticket/issue number. 

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
  * Update your [Jira](https://tickets.puppetlabs.com/issues/?jql=project%20%3D%20BKR) ticket to mark that you have submitted code and are ready for it to be considered for merge (Status: Ready for Merge).
    * Include a link to the pull request in the ticket.
* PRs are reviewed as time permits.  

# Additional Resources

* [Puppet community guidelines](https://docs.puppet.com/community/community_guidelines.html)
* [Bug tracker (Jira)](http://tickets.puppetlabs.com)
* [BKR Jira Project](https://tickets.puppetlabs.com/issues/?jql=project%20%3D%20BKR)
* [Contributor License Agreement](http://links.puppetlabs.com/cla)
* [General GitHub documentation](http://help.github.com/)
* [GitHub pull request documentation](http://help.github.com/send-pull-requests/)
* Questions?  Comments?  Contact the Beaker team at the #puppet-dev IRC channel on freenode.org
  * The keyword `beaker` is monitored and we'll get back to you as quick as we can.
