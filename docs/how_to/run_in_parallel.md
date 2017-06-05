# run_in_parallel global and command options

## run_in_parallel global option
The run_in_parallel global option is an array with the following possible values: ['configure', 'install']
It defaults to an empty array []
It can be set in an options file, or overriden by the BEAKER_RUN_IN_PARALLEL environment variable
example:

export BEAKER_RUN_IN_PARALLEL=configure,install

Including 'configure' causes timesync to execute in parallel (if timesync=true for any host)

Including 'install' causes as much of the puppet install to happen in parallel as possible.

## run_in_parallel command option
The run_in_parallel command option is a boolean value, specifying whether to execute each iteration (usually of hosts)
in parallel, or not.  The block_on method is the primary method accepting the run_in_parallel command option,
however many methods that call into block_on respect it as well:
- on
- run_block_on
- block_on
- install_puppet_agent_on
- apply_manifest_on
- stop_agent_on
- execute_powershell_script_on

## Using InParallel in your test scripts
In addition to the options, you can use InParallel within your test scripts as well.

Examples:
```ruby
include InParallel

test_name('test_test')

# Example 1
hosts.each_in_parallel{ |host|
    # Do something on each host
}

def some_method_call
    return "some_method_call"
end

def some_other_method_call
    return "some_other_method_call"
end

# Example 2
# Runs each method within the block in parallel in a forked process
run_in_parallel{
    @result = some_method_call
    @result_2 = some_other_method_call
}

# results in 'some_method_callsome_other_method_call'
puts @result + @result_2
```

**_Note:_** While you can return a result from a forked process to an instance variable, any values assigned to local variables, or other changes to global state will not persist from the child process to the parent process.

Further documentation on the usage of [InParallel](http://github/puppetlabs/in-parallel/readme.md)
