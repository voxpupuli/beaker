## The Task

We will write a test to check if a package (specifically HTTPD) is installed and running. To do this we will write two files:
1. `install.rb` - This file will install the package and start the service
2. `mytest.rb` - This file will have our core tests that checks if the package is installed and running

Note: We will exclude Windows OS from our testing due to variation of package name.

## Figure out steps

What needs to happen in this test:

* Install and run HTTPD
  * Install HTTPD if its not available on our SUT
  * Start HTTPD service
* Testing
  * Test HTTPD is installed
  * Test HTTPD service is running

## Create a host configuration file
    $ beaker-hostgenerator redhat7-64 > redhat7-64.yaml

This command will generate a host file for our system under test (SUT). It will use vmpooler as hypervisor for the host. Please check out [this](https://github.com/puppetlabs/beaker/tree/master/docs/how_to/hypervisors) doc to learn more about hypervisors for beaker.

## Install and run HTTPD

Make a file named `install.rb` and put the following code into it:

```ruby
test_name "Installing and runnning HTTPD" do

  # Don't run the install script on the following platform
  confine :except, :platform => 'windows'

  step "Install HTTPD" do
    hosts.each do |host|
      # Install HTTPD if it is not available on our SUT
      install_package(host, 'httpd') unless check_for_package(host, 'httpd')
    end
  end

  step "Start HTTPD" do
    hosts.each do |host|
      # Start HTTPD service
      on(host, "service httpd start")
    end
  end

end
```

This places our install steps in a ruby script (`install.rb`) which will run on your SUT. The install.rb script is used in our commandline to beaker, below.

## Create a test file

Lets create test file that tests if HTTPD is installed and running on our hosts. Make a file called `mytest.rb` and add the following code to it:

```ruby
test_name "Check if HTTPD is installed and running" do

  # Don't run these tests on the following platform
  confine :except, :platform => 'windows'

  step "Make sure HTTPD is installed" do
    hosts.each do |host|
      # Check if HTTPD is installed
      assert check_for_package(host, 'httpd')
    end
  end

  step "Make sure HTTPD is running" do
    hosts.each do |host|
      on(host, "systemctl is-active httpd") do |result|
        # Check if HTTPD is running
        assert_equal(0, result.exit_code)
      end
    end
  end

end
```

## Run it!
You can now run this with

    beaker --host redhat7-64ma.yaml --pre-suite install.rb --test mytest.rb

Next up you may want to look at the [Beaker test for a module](../how_to/write_a_beaker_test_for_a_module.md) page.
