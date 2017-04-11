# The Task

Verify that `cowsay` works when installed on a host

# Figure Out Test Steps

What needs to happen in this test:

* Prep by installing & verifying `cowsay` is on the system
* Run `cowsay` & assert that it did not fail

# Create a host  file

```bash
$ beaker-hostgenerator --global-config {add_el_extras=true} centos6-64 > centos6-64.yaml
```

The `--global-config {add_el_extras=true}` part adds the `add_el_extras: true`
line to the global config section of the hosts file. With this setting enabled,
beaker will ensure that the
[Extra Packages for Enterprise Linux (EPEL)](https://fedoraproject.org/wiki/EPEL)
are setup on the hosts as a part of beaker's host setup after the VMs are
provisioned.

# Create a test file

We need to create a test file to run.

## Install & verify that `cowsay` is on the host

beaker's [Host object](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/Host)
provides a number of convenience methods that abstract away Operating System (OS)
-specific details. We'll use a few of these to do what we'd like:

- [`check_for_package`](http://www.rubydoc.info/github/puppetlabs/beaker/Unix/Pkg:check_for_package)
- [`install_package`](http://www.rubydoc.info/github/puppetlabs/beaker/Unix/Pkg:install_package)

A step that checks for our `cowsay` package & installs it could look like this:
```ruby
unless default.check_for_package('cowsay')
  default.install_package('cowsay')
end
   
assert(default.check_for_package('cowsay'))
```

beaker's assertions are based in [minitest](https://github.com/seattlerb/minitest)'s
and a few helpers of our own have been added on top of that. Checkout the
[Assertions rubydocs](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Assertions)
for more information on that.

## Run `cowsay` & Verify it Exited Without an Error
 
For this, we'll introduce you to the heart of beaker execution, the
[`on` method](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers:on).
This method runs commands similarly to saying the phrase:

    on hostX, run commandZ

So to run & verify our `cowsay` command, we can have a step like this one:
```ruby
result = on(default, 'cowsay pants pants pants')

assert(result.exit_code == 0)
```

In beaker, when you run `on`, you get a
[Result object](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/Result)
back. We can assert against its `exit_code` accessor to make sure it exited
successfully, as you see above.

## Put it all together

Here's the finished acceptance test.

```ruby
test_name 'Cowsay works for the Let\'s Write a Test doc' do
  confine :to, :platform => 'el'
  
  package = 'cowsay'
  step "make sure #{package} is on the host" do
    unless default.check_for_package(package)
      default.install_package(package)
    end
   
    assert(default.check_for_package(package))
  end
  
  step "verify #{package} executes without error codes" do
    result = on(default, "#{package} pants pants pants")
    
    assert(result.exit_code == 0)
  end
end
```

You'll notice there's some structure around the code that we talked about before.
`test_name` & `step` are structural beaker domain-specific language (DSL)
methods that help you organize your tests & the output from beaker itself. To
learn more about best practices in beaker test writing, checkout our
[Style Guide](../concepts/style_guide.md).

You'll also notice that we're using the `confine` method. Confining allows you
to skip tests in certain situations. Skipped tests are reported separately from
tests that return results. For this scenario, we're confining this test to
`el`-platforms. To learn more about how confining works, checkout our
[How-To Confine doc](../how_to/confine.md).

# Run it!
If we saved the test above into a `cowsay.rb` file, then you can run the tests
with this command:
```bash
$ beaker --host centos6-64.yaml --test cowsay.rb
```

Congrats! You've run beaker with your new test!

Return to the [Tutorials Section](../) README to continue learning about beaker!
