# Debug beaker tests

beaker includes [pry-byebug](https://github.com/deivid-rodriguez/pry-byebug), a gem that combines two powerful related tools: pry and byebug

### What is Pry?

[Pry](http://pryrepl.org/) is a powerful Ruby editing and debugging tool.  Beaker uses Pry runtime invocation to create a developer console.

### What is byebug?
[Byebug](https://github.com/deivid-rodriguez/byebug) is a powerful debugger for ruby. It allows for flexible control of breakpoints, stepping through lines or the call stack. It lacks some features of pry such as source code editing and replaying code execution from within the debugging session, but can be used in combination with pry.

There are several ways to have your tests break and enter debugging:

 1. [Add a breakpoint to your test file](#add-a-breakpoint-to-your-test-file)
 2. [Use the --debug-errors option](#use-the---debug-errors-option)
 3. [Defining external breakpoints with byebug](#defining-external-breakpoints-with-byebug)

## Add a breakpoint to your test file

Add Pry to individual tests by adding `require 'pry'` to the Ruby test file.
Then add the statement `binding.pry` at the point in code where you want access to the full, current Beaker environment.

### Example
#### Example test trypry.rb
Here's a test file that exercises different ways of running commands on Beaker hosts.  At the end of the main `hosts.each` loop I've included `binding.pry` to invoke the console.

```
hosts.each do |h|
  on h, "echo hello"
  if h['platform'] =~ /windows/
    scp_to h, "beaker.gemspec", "/cygdrive/c/Documents\ and\ Settings/All\ Users/Application\ Data/"
  end
  on(h, "echo test block") do |result|
      puts "block result.stdout: #{result.stdout}"
      puts "block result.raw_stdout: #{result.raw_stdout}"
  end
  on(h, "echo test block, built in functions") do
      puts "built in function stdout: #{stdout}"
      puts "built in function stderr: #{stderr}"
  end

  result = on(h, "echo no block")
  puts "return var result.stdout: #{result.stdout}"
  puts "return var result.raw_stdout: #{result.raw_stdout}"

  binding.pry

end
```

#### Sample output to the first `binding.pry` call:
```
$ bundle exec beaker --tests tests/trypry.rb --hosts configs/fusion/winfusion.cfg --no-provision
{
    "project": "Beaker",
    ...
    "helper": [],
    "load_path": [],
    "pre_suite": [],
    "post_suite": [],
    "install": [],
    "modules": [],
    "logger": "#<Beaker::Logger:0x007f925a6b4218>"
}
Hypervisor for pe-centos6 is none
Hypervisor for w2k8r2 is none
Hypervisor for w2k3r2 is none
Beaker::Hypervisor, found some none boxes to create

pe-centos6 10:55:27$  which curl  
/usr/bin/curl

pe-centos6 executed in 0.14 seconds

pe-centos6 10:55:27$  which ntpdate  
/usr/sbin/ntpdate

pe-centos6 executed in 0.01 seconds

w2k8r2 10:55:27$  which curl  
/bin/curl

w2k8r2 executed in 0.42 seconds

w2k3r2 10:55:27$  which curl  
/bin/curl

w2k3r2 executed in 0.29 seconds
No tests to run for suite 'pre_suite'
Begin tests/trypry.rb

pe-centos6 10:55:28$  echo hello  
hello

pe-centos6 executed in 0.01 seconds

pe-centos6 10:55:28$  echo test block  
test block

pe-centos6 executed in 0.01 seconds
block result.stdout: test block
block result.raw_stdout: test block

pe-centos6 10:55:28$  echo test block, built in functions  
test block, built in functions

pe-centos6 executed in 0.00 seconds
built in function stdout: test block, built in functions
built in function stderr:

pe-centos6 10:55:28$  echo no block  
no block

pe-centos6 executed in 0.00 seconds
return var result.stdout: no block
return var result.raw_stdout: no block

From: /Users/anode/beaker/tests/trypry.rb @ line 19 self.run_test:

    14:
    15:   result = on(h, "echo no block")
    16:   puts "return var result.stdout: #{result.stdout}"
    17:   puts "return var result.raw_stdout: #{result.raw_stdout}"
    18:
 => 19:   binding.pry
    20:
    21: end

[1] pry(#<Beaker::TestCase>)>
```
#### Using the console
At this point I have access to the console.  I have full access to Beaker hosts, the Beaker DSL and Ruby.

Here's some sample console calls:
```
[1] pry(#<Beaker::TestCase>)> hosts
=> [pe-centos6, w2k8r2, w2k3r2]
[2] pry(#<Beaker::TestCase>)> on hosts[1], 'echo hello'

w2k8r2 10:54:11$  echo hello  
hello

w2k8r2 executed in 0.07 seconds
=> #<Beaker::Result:0x007f9f6b7a3408
 @cmd=" echo hello  ",
 @exit_code=0,
 @host="w2k8r2",
 @output="hello\n",
 @raw_output="hello\n",
 @raw_stderr="",
 @raw_stdout="hello\n",
 @stderr="",
 @stdout="hello\n">
[3] pry(#<Beaker::TestCase>)> on hosts[1], 'ls /cygdrive/c/Documents\ and\ Settings/All\ Users/Application\ Data/'

w2k8r2 10:56:15$  ls /cygdrive/c/Documents\ and\ Settings/All\ Users/Application\ Data/  
Application Data
Desktop
Documents
Favorites
Microsoft
Package Cache
Start Menu
Templates
VMware
beaker.gemspec
ntuser.pol

w2k8r2 executed in 0.09 seconds
=> #<Beaker::Result:0x007f925b227898
 @cmd=
  " ls /cygdrive/c/Documents\\ and\\ Settings/All\\ Users/Application\\ Data/  ",
 @exit_code=0,
 @host="w2k8r2",
 @output=
  "Application Data\nDesktop\nDocuments\nFavorites\nMicrosoft\nPackage Cache\nStart Menu\nTemplates\nVMware\nbeaker.gemspec\nntuser.pol\n",
 @raw_output=
  "Application Data\nDesktop\nDocuments\nFavorites\nMicrosoft\nPackage Cache\nStart Menu\nTemplates\nVMware\nbeaker.gemspec\nntuser.pol\n",
 @raw_stderr="",
 @raw_stdout=
  "Application Data\nDesktop\nDocuments\nFavorites\nMicrosoft\nPackage Cache\nStart Menu\nTemplates\nVMware\nbeaker.gemspec\nntuser.pol\n",
 @stderr="",
 @stdout=
  "Application Data\nDesktop\nDocuments\nFavorites\nMicrosoft\nPackage Cache\nStart Menu\nTemplates\nVMware\nbeaker.gemspec\nntuser.pol\n">
[4] pry(#<Beaker::TestCase>)> result = on hosts[1], 'ls /cygdrive/c/Documents\ and\ Settings/All\ Users/Application\ Data/'

w2k8r2 10:56:34$  ls /cygdrive/c/Documents\ and\ Settings/All\ Users/Application\ Data/  
Application Data
Desktop
Documents
Favorites
Microsoft
Package Cache
Start Menu
Templates
VMware
beaker.gemspec
ntuser.pol

w2k8r2 executed in 0.08 seconds
=> #<Beaker::Result:0x007f925a387018
 @cmd=
  " ls /cygdrive/c/Documents\\ and\\ Settings/All\\ Users/Application\\ Data/  ",
 @exit_code=0,
 @host="w2k8r2",
 @output=
  "Application Data\nDesktop\nDocuments\nFavorites\nMicrosoft\nPackage Cache\nStart Menu\nTemplates\nVMware\nbeaker.gemspec\nntuser.pol\n",
 @raw_output=
  "Application Data\nDesktop\nDocuments\nFavorites\nMicrosoft\nPackage Cache\nStart Menu\nTemplates\nVMware\nbeaker.gemspec\nntuser.pol\n",
 @raw_stderr="",
 @raw_stdout=
  "Application Data\nDesktop\nDocuments\nFavorites\nMicrosoft\nPackage Cache\nStart Menu\nTemplates\nVMware\nbeaker.gemspec\nntuser.pol\n",
 @stderr="",
 @stdout=
  "Application Data\nDesktop\nDocuments\nFavorites\nMicrosoft\nPackage Cache\nStart Menu\nTemplates\nVMware\nbeaker.gemspec\nntuser.pol\n">
[5] pry(#<Beaker::TestCase>)> result.stdout.chomp
=> "Application Data\nDesktop\nDocuments\nFavorites\nMicrosoft\nPackage Cache\nStart Menu\nTemplates\nVMware\nbeaker.gemspec\nntuser.pol"
```
#### Continue regular test execution
Simply `exit` the console.
```
[6] pry(#<Beaker::TestCase>)> exit
```

## Use the --debug-errors option

You can run beaker and pass the option `--debug-errors` to have beaker enter the pry console if or when a test error occurs. This is useful for transient/intermittent errors where you may need to run the test a large number of times before seeing the failure. It's also useful to keep your hosts at the state where error occurred, as the test's teardown will not (yet) have executed.

### Example

Consider this example test case _test.rb_, which is going to fail:

    test_name 'An important aspect of my product'

    important_expected_value = 3

    step 'Assert expected matches actual' do
      actual_value = 2
      assert_equal(important_expected_value, actual_value, 'This product is faulty')
    end

You can run this test using `beaker -t test.rb` or (to use the `run` subcommand and just run the test and bypass host provisioning etc) `beaker run -t test.rb`  
It fails.

Now try `beaker run -t test.rb --debug-errors`  
This will enter a pry console when the failure occurs.

    * Assert expected matches actual
      Exception raised during step execution and debug-errors option is set, entering pry. Exception was: #<Minitest::Assertion: This product is faulty.
       Expected: 3
        Actual: 2>
      HINT: Use the pry 'backtrace' and 'up' commands to navigate to the test code
    
    From: /home/puppet/code/beaker/lib/beaker/dsl/structure.rb @ line 51 Beaker::DSL::Structure#step:
    
        38: def step step_name, &block
        39:   logger.notify "\n* #{step_name}\n"
        40:   set_current_step_name(step_name)
        41:   if block_given?
        42:     logger.step_in()
        43:     begin
        44:       yield
        45:     rescue Exception => e
        46:       if(@options.has_key?(:debug_errors) && @options[:debug_errors] == true)
        47:         logger.info("Exception raised during step execution and debug-errors option is set, entering pry. Exception was: #{e.inspect}")
        48:         logger.info("HINT: Use the pry 'backtrace' and 'up' commands to navigate to the test code")
        49:         binding.pry
        50:       end
     => 51:       raise e
        52:     end
        53:     logger.step_out()
        54:   end
        55: end
    
    [1] pry(#<Beaker::TestCase>)>

Because beaker is catching the exception, pry is showing you beaker code. But you can navigate to your own test code using the `backtrace` and `up` commands.

`backtrace` shows output like:

    [1] pry(#<Beaker::TestCase>)> backtrace
    --> #0  rescue in Beaker::DSL::Structure.rescue in step(step_name#String, &block#Proc) at /home/puppet/code/beaker/lib/beaker/dsl/structure.rb:51
        #1  Beaker::DSL::Structure.step(step_name#String, &block#Proc) at /home/puppet/code/beaker/lib/beaker/dsl/structure.rb:43
        #2  block in #<Class:#<Beaker::TestCase:0x00000001761848>>.block in run_test at /home/puppet/code/beaker/test.rb:5
        I+--- #3  Kernel.eval(*args) at /home/puppet/code/beaker/lib/beaker/test_case.rb:133
        #4  block in #<Class:#<Beaker::TestCase:0x00000001761848>>.block in run_test at /home/puppet/code/beaker/lib/beaker/test_case.rb:133

The arrow indicates pry is showing code at the top of the stack trace. At position #2 in the stack you can see line 5 of test.rb - this is the actual test code that failed. You can navigate there by entering the `up` command twice.

        From: /home/puppet/code/beaker/test.rb @ line 5 self.run_test:
    
        1: test_name 'An important aspect of my product'
        2:
        3: important_expected_value = 3
        4:
     => 5: step 'Assert expected matches actual' do
        6:   actual_value = 2
        7:   assert_equal(important_expected_value, actual_value, 'This product is faulty')
        8: end
    
    [2] pry(#<Beaker::TestCase>)>

> **NOTE:** Bear in mind that though you are navigating through your code here; pry is not rewinding code execution. When you exit pry, beaker will continue its execution from the top of the backtrace, failing the test due to the error that occurred.

From here, you can examine variables in your test. If you have hosts provisioned, you can send them commands using the [on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#on-instance_method) method, or in a separate terminal ssh into them to investigate their state at the point of failure.

## Defining external breakpoints with byebug
This method is perhaps the least intuitive to use; but combines the advantages of letting you pick the line(s) of code to set breakpoints on; and being able to debug without needing to edit your test code directly. It is sometimes desirable to debug a test without changing the test's code at all; for example, if you want to compare a test at two or more different git commits, your test source needs to remain unmodified from its committed form.

byebug allows you to externally define breakpoints to keep them separate from your source code. 

### Example
Consider the following test file test.rb:

```ruby
test_name 'An important aspect of my product'

important_expected_value = 3

step 'Assert expected matches actual' do
  actual_value = 2
  assert_equal(important_expected_value, actual_value, 'This product is faulty')
end
```

If you wanted to debug at line 6 to investigate the state of your System Under Test before the failing assertion executes, then create a file in your working directory named .byebugrc with contents:

```
break test.rb:7
```

You can then run beaker within byebug like this:

```
[centos@test-development project]$ bundle exec byebug beaker -t test.rb

[4, 13] in /home/puppet/code/beaker/vendor/bundle/ruby/2.3.0/bin/beaker
    4: #
    5: # The application 'beaker' is installed as part of a gem, and
    6: # this file is here to facilitate running it.
    7: #
    8:
=>  9: require 'rubygems'
   10:
   11: version = ">= 0.a"
   12:
   13: if ARGV.first
(byebug)
```

Note that byebug has immediately stopped at the first line of beaker and awaits your command. Type 'continue' to command byebug to continue execution until it next hits a breakpoint.

```
    8:
=>  9: require 'rubygems'
   10:
   11: version = ">= 0.a"
   12:
   13: if ARGV.first
(byebug) continue
Beaker!
      wWWWw
      |o o|
      | O |  3.18.0!
      |(")|
     / \X/ \
    |   V   |
    |   |   |
{
    "project": "Beaker",
    "department": "unknown",
    "created_by": "centos",
    "host_tags": {},
    "openstack_api_key": null,
    "openstack_username": null,
...
    "timestamp": "2017-06-23 13:21:11 +0000",
    "beaker_version": "3.18.0",
    "log_prefix": "beaker_logs",
    "xml_dated_dir": "junit/beaker_logs/2017-06-23_13_21_11",
    "log_dated_dir": "log/beaker_logs/2017-06-23_13_21_11",
    "logger_sut": "#<Beaker::Logger:0x000000034a2998>"
}
No tests to run for suite 'pre_suite'
Begin test.rb

An important aspect of my product

* Assert expected matches actual
Stopped by breakpoint 1 at test.rb:7

[1, 8] in test.rb
   1: test_name 'An important aspect of my product'
   2:
   3: important_expected_value = 3
   4:
   5: step 'Assert expected matches actual' do
   6:   actual_value = 2
=> 7:   assert_equal(important_expected_value, actual_value, 'This product is faulty')
   8: end
(byebug)
```

You can now debug at this point in the file using [byebug commands](https://github.com/deivid-rodriguez/byebug#byebugs-commands)
