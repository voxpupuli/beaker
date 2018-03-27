# Enabling access bewteen SUTs during an acceptance test run

If you are running acceptance tests for Beaker that, at some point, will perform one of the following:

* SSH between SUTs
* Clone private repos

You will need to run an SSH agent, and add the SSH key for accessing your SUTs/private repos, prior to running the tests.

To load the SSH agent and add your SSH key, run the following:

~~~bash
eval `ssh-agent`
ssh-add <SSH key file path>
~~~

A common example of where this functionality would be required for beaker developers, is in testing subcommands. There, we setup multiple SUTs that need to communicate between themselves. To run our subcommand testing to verify that you have agent forwarding setup correctly, run the following:

~~~bash
beaker --tests acceptance/tests/subcommands/ --log-level debug --preserve-hosts onfail --pre-suite acceptance/pre_suite/subcommands/ --load-path acceptance/lib --keyfile ~/.ssh/id_rsa-acceptance
~~~

And Beaker will be able to SSH between SUTs and clone private repos
