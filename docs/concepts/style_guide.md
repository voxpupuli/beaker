# Beaker Style Guide

## Scope of this guide

The purpose of this guide is to provide definitions for best practices when writing Beaker tests, both syntactically and stylistically. This guide will define and provide examples for preferred test layout and conventions. Common patterns that are recommended as well as patterns that should be avoided will be described.

No style manual can cover every possible circumstance. When a judgement call becomes necessary, keep in mind the following general ideas:

1. **Readability matters**. If you have to choose between two equally effective alternatives, pick the more readable one. This is, of course, subjective, but if you can read your own code three months from now, that's a great start. Don't be clever over readable, unless you have a documented purpose. Use object oriented programming when things get complex and [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself).
2. **Inherit upstream conventions**. Beaker is still ruby, so use the [ruby community style guide](https://github.com/bbatsov/ruby-style-guide). When not called out here, use the ruby style guide.

## Test Naming

Tests should test what they say they test. Test names, both the name of the test file and the value given to the [`test_name`](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#test_name-instance_method) function, should provide an accurate indication about the purpose of the test.

The `test_name` function should be the first line in the Beaker test file.

**Good:**
```ruby
# head -1 puppet/acceptance/tests/resource/file/should_default_mode.rb
test_name "file resource: set default modes" do
```

## Structure Methods Should Use Explicit Blocks

These methods aid in self-documenting your tests, including indention in the logs. If you don't use explicit blocks, beaker does not know how to properly indent your test's output.

The most common [structure methods](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure) are [`#test_name`](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#test_name-instance_method), [`#step`](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#step-instance_method), and [`#teardown`](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#teardown-instance_method).

**Good:**
```ruby
step 'do this thang' do
  on(host, "echo 'do this thang'")
end
```
**Bad:**
```ruby
step 'do this thang'
on(host, "echo 'do this thang'")
```

## Teardowns

- Return the state of the system to the way it was prior to test execution
- Put the teardown as early in the test as possible

Teardowns must be used to return the system to the state it was in prior to the execution or attempted execution of the test. Beaker will gather all teardowns encountered throughout the execution path of the test. These teardowns will all be executed when the test exits, even if the test exits early due to a failure or error.

### Place Teardowns Early

Teardowns can be placed anywhere in the test file or its helpers. The preferred style is to have a teardown step near the beginning of the test file to show the reader that the system state will be restored.

**Good:**
```ruby
test_name 'The source attribute' do

  target_file_on_nix = '/tmp/source_attr_test'
  teardown do
    hosts.each do |host|
      on(host, "rm #{target_file_on_nix}", :accept_all_exit_codes => true) unless host['platform'].start_with('win')
    end
  end
  ...
end
```

Teardowns are at the mercy of the scoping of the variables necessary to perform the restoration of the system. This fact means that additional teardown steps will need to be added within the scope necessary to do their job. Effort should be taken to make the teardown steps prominent and readable so that it can be confirmed, via the logs, that the system has been restored.

Teardown steps registered outside of tests should use [`#step`](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#step-instance_method) to document and log what they are doing.

## Acceptable Exit Codes

When using the Beaker [`on`](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#on-instance_method) method, the default setting is that only an exit code of 0 (zero) will not trigger an error. When other exit codes are acceptable, the `:acceptable_exit_codes` key with an array of exit codes should be passed in the options hash to `#on`. If 0 (zero) is the only acceptable exit code, then the `:acceptable_exit_codes` symbol must not be used.

**Good:**

- Single 0 exit code allowed
```ruby
on(host, "rm #{file_to_rm}")
```
- Single non-0 exit code allowed
```ruby
on(host, "rm #{file_to_rm}", :acceptable_exit_codes => 1)
```
- Multiple exit codes allowed
```ruby
on(host, "rm #{file_to_rm}", :acceptable_exit_codes => [0,1])
```
- Any exit code allowed
```ruby
on(host, "rm #{file_to_rm}", :accept_all_exit_codes => true)
```

In the last case, when any exit code is allowed, one must follow-up with a valid assertion test.

If an exit_code outside of 0 is expected, one must use acceptable_exit_codes so the test will fail on the proper assertion and not error at that command.  Allow only the minimum expected set of exit codes unless coverage is provided by subsequent assertions.

## Test Outcomes

When to use each, and how to format the message:

### Expecting Failure

If your tests are failing due to an "expected failure", you should wrap your failing assertion in an [`expect_failure`](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#expect_failure-instance_method) block with an explanatory logging message:

```ruby
expect_failure('expected to fail due to PE-1234') do
  assert_equal(400, response.code, 'bad response code from API call')
end
```

Note that `expect_failure` will only trigger from failed assertions. It won't take care of failed host or `on` commands. To deal with expected failure from an `on` invocation, you'd want something more like this:

```ruby
on(blah, 'blah', :allow_all_exit_codes => true) do |result|
  expect_failure 'known issue: TIK-1234' do
    assert_equal(4,result.exit_code,'did not receive expected exit code for blah')
  end
end
```

### `fail_test`, `pass_test`, & `skip_test`

These can be used anywhere in a test to exit early. A [`skip_test`](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Outcomes#fail_test-instance_method) between two assertions, for instance, will run the first assertion, raise an exception for `skip_test`, run teardown, and then exit as we expect. The same is true for [fail_test](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Outcomes#fail_test-instance_method).

[`pass_test`](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Outcomes#fail_test-instance_method) is typically not required. When the end of a test is reached without causing an error (due to bad test code execution, or an unhandled exit code or exception) or failure (due to assertions), then it passes.

`pass_test` can be used in a situation where one knows a test has passed before the end of a test under certain circumstances, such as during a loop that has not yet completed.

### Skipping Tests

Skipping tests can be used, for instance, when they are temporarily failing or not yet complete.

**Good:**
```ruby
skip_test 'requires puppet and mcollective service scripts from AIO agent package' if @options[:type] != 'aio'
```
**Bad:**
```ruby
confine :to, :platform => 'solaris:pending'
```

## Confining

Another way that you can skip or manipulate tests is by confining them to apply to a subset of the SUTs available for testing. Confining is a complex topic, and one we don't have the length to get into in the style guide. For an explanation of confining, as well as the best practices in using it, check out our [confine doc](../how_to/confine.md).

## Assertions

Always include a _unique_ error message in your assertion statement. Use strict asserts whenever possible (e.g. assert_equal, assert_match. [More info](http://danwin.com/2013/03/ruby-minitest-cheat-sheet/)).
