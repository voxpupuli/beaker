## The Task

We will write an acceptance test to check if a package (specifically NTP) is installed on a host or not.

## Figure Out Test Steps

What needs to happen in this test:

* Install NTP
* Check to see if NTP is installed successfully on host or not

## Create a host configuration file
We will be using a host from vmpooler. You can edit the host file to use other hypervisors like vagrant, but this document is supported for vmpooler as of now.

    $ beaker-hostgenerator redhat7-64ma > redhat7-64ma.yaml

## Install NTP

We prefer to install NTP first and then run a set of tests, so NTP installation should not be part of the actual acceptance test. Create and add the following code to a file called `install.rb`.

```ruby
test_name "Installing NTP" do
	hosts.each do |host|
		install_package(host, 'ntp')
	end
end
```

This places our install steps in a ruby script (install.rb) which will run on our host. The `install_package` method knows where and how to install NTP based on the host configuration in use. The install.rb script is used in our commandline to beaker, below.

## Create a test file

We need to create a test file to run. Make a file called `mytest.rb` and add the following test that checks if ntp is installed or not.

```ruby
test_name "NTP installation check"

# Don't run these tests on the following platform
confine :except, :platform => 'windows'

step "Make sure NTP is installed"
hosts.each do |host|
  # Check to make sure only one process is running
  check_for_package(host, 'ntp') { assert_equal(true) }
end
```

## Run it!
You can now run this with

    beaker --host redhat7-64ma.yaml --pre-suite install.rb --tests mytest.rb

Next up you may want to look at the [Beaker test for a module](../how_to/write_a_beaker_test_for_a_module.md) page.
