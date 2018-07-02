# How To Contribute To Beaker

Contributions are welcomed. Simple bug fixes and minor enhancements will usually be accepted. Larger features should be discussed with a team member before you invest in developing them with the expectation that they will be merged.

## Getting Started

Beaker does not use GitHub Issues, but an internal ticketing system running Jira that interfaces with other services. To be accepted by the maintainers, changes must follow this workflow and tagging scheme. See [ticket process doc](docs/concepts/ticket_process.md) for a

* Create a [Jira account](http://tickets.puppetlabs.com).
* Make sure you have a [GitHub account](https://github.com/signup/free).
* Submit a ticket for your issue on Jira, assuming one does not already exist.
  * Clearly describe the issue including steps to reproduce when it is a bug.
  * File the ticket in the [BKR project](https://tickets.puppetlabs.com/issues/?jql=project%20%3D%20BKR).
* Fork the [Beaker repository on GitHub](https://github.com/puppetlabs/beaker).
* [Get Beaker set up for development](docs/tutorials/installation.md#for-development).

## Making Changes

Contributions are accepted in the form of pull requests against the master branch on GitHub.

* Create a topic branch on your fork of [puppetlabs/beaker](https://github.com/puppetlabs/beaker) based on `master`.
* Make commits of logical units. If your commits are a mess, you will be asked to [rebase or at least squash](https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History) your PR.
  * Check for unnecessary whitespace with `git diff --check` before committing.
* Make sure your commit messages are in the proper format:
  ```
    (BKR-1234) Make the example in CONTRIBUTING imperative and concrete

    Without this patch applied the example commit message in the CONTRIBUTING document is not a concrete example.  This is a problem because the contributor is left to imagine what the commit message should look like based on a description rather than an example.  This patch fixes the problem by making the example concrete and imperative.

    The first line is a real life imperative statement with a ticket number from our issue tracker.  The body describes the behavior without the patch, why this is a problem, and how the patch fixes the problem when applied.
  ```
* During the time that you are working on your patch the master Beaker branch may have changed - be sure to [rebase](http://git-scm.com/book/en/Git-Branching-Rebasing) on top of [Beaker's](https://github.com/puppetlabs/beaker) master branch before you submit your PR.  A successful rebase ensures that your PR will merge cleanly.
* When you're ready for review, create a new pull request.

#### PR Requirements

Pull Requests are subject to the following requirements:

* Commits must be logical units. Follow these [basic guidelines](https://github.com/trein/dev-best-practices/wiki/Git-Commit-Best-Practices#basic-rules), and don't be afraid to make too many commits: it's always easier to squash than to fixup.
* Must not contain changes unrelated to the ticket being worked on. Issues you encounter as directly related to the main work for a ticket are fiar game. Many beaker components only get infrequent updates so it is not uncommon to encounter dependency version changes that cause problems. These can be addressed with a `(MAINT)` commit within the feature PR you're working on. Larger or only peripherally related changes should go through their own ticket, which you can create; tickets with attached PRs are generally accepted.
* Must merge cleanly. Only fast-forward merges are accepted, so make sure the PR shows as a clean merge.
* On that note, merge commits are not accepted. In order to keep your feature branch up-to-date and ensure a clean merge, you should [rebase](http://git-scm.com/book/en/Git-Branching-Rebasing) on top of beaker's master. You can also use this opportunity to keep your fork up to date. That workflow looks like this:
    ~~~console
    you@local:beaker $ git checkout master
    Switched to branch 'master'
    Your branch is up to date with 'origin/master'.
    you@local:beaker $ git fetch upstream
    you@local:beaker $ git merge upstream/master
    Updating a01b5732..a565e1ac
    Fast-forward
     lib/beaker/logger.rb       | 2 +-
     spec/beaker/logger_spec.rb | 4 ++++
     2 files changed, 5 insertions(+), 1 deletion(-)
    you@local:beaker $ git push
    Total 0 (delta 0), reused 0 (delta 0)
    To https://github.com/Dakta/beaker.git
       a01b5732..a565e1ac  master -> master
    you@local:beaker $ git checkout BKR-816
    Switched to branch 'BKR-816'
    you@local:beaker $ git rebase master
    # if you have conflicts, they'll appear here. Manually fix the listed files then use `git rebase --continue`. Repeat as necessary for each conflicting commit.
    First, rewinding head to replay your work on top of it...
    Fast-forwarded BKR-816 to master.
    you@local:beaker $ git push --set-upstream origin BKR-816
    Counting objects: 9, done.
    Delta compression using up to 8 threads.
    Compressing objects: 100% (9/9), done.
    Writing objects: 100% (9/9), 2.05 KiB | 2.05 MiB/s, done.
    Total 9 (delta 6), reused 0 (delta 0)
    remote: Resolving deltas: 100% (6/6), completed with 6 local objects.
    To https://github.com/Dakta/beaker.git
     + [new branch]        BKR-816 -> BKR-816
    Branch 'BKR-816' set up to track remote branch 'BKR-816' from 'origin'.
    ~~~

#### Courtesy

Please do not introduce personal ignores into the `.gitignore`, such as IDE configurations, editor version files, or personal testing artefacts. You may find it valuable to add the first two to [a global ignore](https://help.github.com/articles/ignoring-files/#create-a-global-gitignore), and the third to [a repository-level ignore](https://help.github.com/articles/ignoring-files/#explicit-repository-excludes).

### Testing

Submitted PR's will be tested in a series of spec and acceptance level tests - the results of these tests will be evaluated by a Beaker team member, as acceptance test results are not accessible by the public. Testing failures that require code changes will be communicated in the PR discussion.

* Make sure you have added [RSpec](http://rspec.info/) tests that exercise your new code.  These test should be located in the appropriate `beaker/spec/` subdirectory.  The addition of new methods/classes or the addition of code paths to existing methods/classes requires additional RSpec coverage.
  * Beaker uses RSpec 3.1.0+, and you should **NOT USE** deprecated `should`/`stub` methods - **USE** `expect`/`allow`. See a nice blog post from 2013 on [RSpec's new message expectation syntax](http://teaisaweso.me/blog/2013/05/27/rspecs-new-message-expectation-syntax/).
  * Run the tests to assure nothing else was accidentally broken, using `rake test`
    * **Bonus**: if possible ensure that `rake test` runs without failures for additional Rubies (versions 1.9.3 and above).

### Documentation

* Add an entry in the [CHANGELOG.md](CHANGELOG.md). Refer to the CHANGELOG itself for message style/form details.
* Make sure that you have added documentation using [YARD](http://yardoc.org/) as necessary for any new code introduced. See [DOCUMENTING](DOCUMENTING.md).
* More user friendly documentation will be required for PRs unless exempted. Documentation lives in the [docs/ folder](docs).

## Making Changes Without a Ticket

The following kinds of changes are made without a corresponding Jira ticket.

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

* Push your changes to a topic branch in your fork of the repository.
* Submit a pull request to [Beaker](https://github.com/puppetlabs/beaker)
* Update your [Jira](https://tickets.puppetlabs.com/issues/?jql=project%20%3D%20BKR) ticket to mark that you have submitted code and are ready for it to be considered for merge (Status: Ready for Merge).

PRs are reviewed as time permits.

# Additional Resources

* [Beaker Glossary](docs/concepts/glossary.md)
* [Puppet community guidelines](https://docs.puppet.com/community/community_guidelines.html)
* [Bug tracker (Jira)](http://tickets.puppetlabs.com)
* [BKR Jira Project](https://tickets.puppetlabs.com/issues/?jql=project%20%3D%20BKR)
* [General GitHub documentation](http://help.github.com/)
* [GitHub pull request documentation](http://help.github.com/send-pull-requests/)
* Questions?  Comments?  Contact the Beaker team at the #puppet-dev IRC channel on freenode.org
  * The keyword `beaker` is monitored and we'll get back to you as quick as we can.
