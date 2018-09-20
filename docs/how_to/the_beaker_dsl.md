# The Beaker DSL

The Beaker [Domain-Specific Language (DSL)](https://en.wikipedia.org/wiki/Domain-specific_language) is a set of Ruby convenience methods provided by Beaker to make testing easier.

Beaker maintains [yard documentation](http://www.rubydoc.info/github/puppetlabs/beaker/) covering the DSL to help you use it. That documentation can sometimes be difficult to navigate, however, so this doc has been created to help you find your way around.

## DSL Caveats

Note that if you're using a beaker-library, any methods provided there won't be documented here. You can refer to the [beaker-libraries listing doc](../concepts/beaker_libraries.md) for links to those projects which should include their own documentation.

Another common point of confusion about the Beaker DSL is that there is a similar set of methods that come along in Host objects themselves. You can tell these methods apart in a test by their invocation method. Host methods are Ruby instance methods on Host objects, so they'll be invoked on a Host object like so:
```ruby
host.host_method_name(host_method_params)
```
and they'll know by default which hosts to act on because you've provided them that through choosing which hosts to call them on. Beaker DSL methods are called in the wider context of the test itself, however, and often need to be passed the hosts you'd like them to act on:
```ruby
on(hosts, "cowsay 'the tortoise lives in agony'")
```
Another way you can tell them apart is their location in the codebase, & thus in the Rubydocs. Beaker DSL methods live under the [Beaker::DSL module](https://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL), whereas Host methods are all included in the [Beaker::Host object itself](https://www.rubydoc.info/github/puppetlabs/beaker/Beaker/Host). Follow that link to the Host Rubydoc and checkout the Instance Method Summary to see a listing of Host methods. Note that they won't be listed here though.

## Assertions

To be used for confirming the result of a test is as expected.  Beaker include all Minitest assertions, plus some custom built assertions.

* [Minitest assertions](http://docs.seattlerb.org/minitest/Minitest/Assertions.html)
* [assert_output](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Assertions#assert_output-instance_method)
* [assert_no_match](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Assertions#assert_no_match-instance_method)

## Helpers

DSL methods designed to help you interact with hosts (like running arbitrary commands on them) or interacting with the web (checking is a given URL is alive or not).

### Host

DSL methods for host manipulation.

* [on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#on-instance_method)
* [shell](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#shell-instance_method)
* [stdout](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#stdout-instance_method)
* [stderr](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#stderr-instance_method)
* [exit_code](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#exit_code-instance_method)
* [scp_from](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#scp_from-instance_method)
* [scp_to](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#scp_to-instance_method)
* [rsync_to](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#rsync_to-instance_method)
* [deploy_package_repo](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#deploy_package_repo-instance_method)
* [create_remote_file](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#create_remote_file-instance_method)
* [run_script_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#run_script_on-instance_method)
* [run_script](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#run_script-instance_method)
* [install_package](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#install_package-instance_method)
* [check_for_package](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#check_for_package-instance_method)
* [upgrade_package](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#upgrade_package-instance_method)
* [add_system32_hosts_entry](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#add_system32_hosts_entry-instance_method)
* [backup_the_file](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#backup_the_file-instance_method)
* [curl_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#curl_on-instance_method)
* [curl_with_retries](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#curl_with_retries-instance_method)
* [retry_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#retry_on-instance_method)
* [run_cron_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#run_cron_on-instance_method)
* [create_tmpdir_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#create_tmpdir_on-instance_method) As of Beaker 4.0, moved to `beaker-puppet`. See [upgrade_from_3_to_4.md](upgrade_from_3_to_4.md).
* [echo_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#echo_on-instance_method)

### Web

Helpers for web actions.

* [port_open_within?](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/WebHelpers#port_open_within?-instance_method)
* [link_exists?](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/WebHelpers#link_exists?-instance_method)
* [fetch_http_file](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/WebHelpers#fetch_http_file-instance_method)
* [fetch_http_dir](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/WebHelpers#fetch_http_dir-instance_method)

### Test

DSL methods for setting information about the current test.

* [current_test_name](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/TestHelpers#current_test_name-instance_method)
* [current_test_filename](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/TestHelpers#current_test_filename-instance_method)
* [current_step_name](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/TestHelpers#current_step_name-instance_method)
* [set_current_test_name](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/TestHelpers#set_current_test_name-instance_method)
* [set_current_test_filename](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/TestHelpers#set_current_test_filename-instance_method)
* [set_current_step_name](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/TestHelpers#set_current_step_name-instance_method)

## Outcomes

Methods that indicate how the given test completed (fail, pass, skip or pending).

* [fail_test](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Outcomes#fail_test-instance_method)
* [pass_test](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Outcomes#pass_test-instance_method)
* [pending_test](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Outcomes#pending_test-instance_method)
* [skip_test](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Outcomes#skip_test-instance_method)
* [formatted_message](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Outcomes#formatted_message-instance_method)

## Patterns

Shared methods used as building blocks of other DSL methods.

* [block_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Patterns#block_on-instance_method)

## Roles

DSL methods for accessing hosts of various roles.

* [agents](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#agents-instance_method)
* [master](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#master-instance_method)
* [database](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#database-instance_method)
* [dashboard](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#dashboard-instance_method)
* [default](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#default-instance_method)
* [not_controller](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#not_controller-instance_method)
* [agent_only](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#agent_only-instance_method)
* [aio_version?](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#aio_version?-instance_method)
* [aio_agent?](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#aio_agent?-instance_method)
* [add_role](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#add_role-instance_method)
* [add_role_def](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#add_role_def-instance_method)
* [any_hosts_as?](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#any_hosts_as?-instance_method)
* [hosts_as](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#hosts_as-instance_method)
* [find_host_with_role](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#find_host_with_role-instance_method)
* [find_only_one](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#find_only_one-instance_method)
* [find_at_most_one](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#find_at_most_one-instance_method)

## Structure

DSL methods that describe and define how a test is executed.

* [step](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#step-instance_method)
* [test_name](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#test_name-instance_method)
* [teardown](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#teardown-instance_method)
* [expect_failure](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#expect_failure-instance_method)
* [confine](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#confine-instance_method)
* [confine_block](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#confine_block-instance_method)
* [tag](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#tag-instance_method)
* [select_hosts](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#select_hosts-instance_method)
* [inspect_host](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#inspect_host-instance_method)
