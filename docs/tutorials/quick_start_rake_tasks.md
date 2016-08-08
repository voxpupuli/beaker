#Beaker Quick Start Tasks

We have developed some rake tasks to help new Beaker users get up and running quickly with writing and running tests.

## Summary

### Gen tasks

These tasks are standalone and can be run independently from each other to generate the desired files.

beaker_quickstart:gen_hosts  (generates default host config)
beaker_quickstart:gen_pre_suite  (generates default pre-suite)
beaker_quickstart:gen_smoke_test  (generates default smoke test)

### Run task

This task will run all the above tasks in sequential order, to generate a hosts file, pre-suite file, smoke test and then use these files
to perform a Beaker test run. If the files already exist (see below for further info on file names and location) then they will not be
overwritten.
 
beaker_quickstart:run_test


## How to use them

To use the tasks, you need to put the following line at the top of your project's rake file:

require 'beaker/tasks/quick_start'

* Note you will need to have already completed the Beaker installation tutorial.

* [Beaker Installation](installation.md)

To check that you have access to the quickstart tasks from your project, run:

    rake --tasks
    
You should see them listed along with any rake tasks you have defined in your local project rakefile:

    rake beaker_quickstart:gen_hosts[provisioner]  # Generate Default Beaker Host Config File, valid options are: vmpooler or vagrant
    rake beaker_quickstart:gen_pre_suite           # Generate Default Pre-Suite
    rake beaker_quickstart:gen_smoke_test          # Generate Default Smoke Test
    rake beaker_quickstart:run_test[provisioner]   # Run Default Smoke Test, after generating default host config and test files, valid options are: vmpooler or vagrant


## Tasks

### gen_hosts

To run:

    rake beaker_quickstart:gen_hosts[provisioner]

This task takes an optional parameter (provisioner), if you leave it empty it will default to 'vmpooler'. You can pass in either 'vmpooler' 
or 'vagrant'.

The gen_hosts task will create a file 'default_provisioner_hosts.yaml' in acceptance/config.

If the file already exists, it will not be overwritten. This will allow you to play around with the config yourself, either by manually 
editing the file or by using beaker-hostgenerator to generate a new hosts config.

Vmpooler file (Ubuntu 14 master and agent):

    ---
    HOSTS:
      redhat7-64-1:
        pe_dir: 
        pe_ver: 
        pe_upgrade_dir: 
        pe_upgrade_ver: 
        hypervisor: vmpooler
        platform: el-7-x86_64
        template: redhat-7-x86_64
        roles:
        - agent
        - master
        - database
        - dashboard
        - classifier
        - default
      redhat7-64-2:
        pe_dir: 
        pe_ver: 
        pe_upgrade_dir: 
        pe_upgrade_ver: 
        hypervisor: vmpooler
        platform: el-7-x86_64
        template: redhat-7-x86_64
        roles:
        - agent
        - frictionless
    CONFIG:
      nfs_server: none
      consoleport: 443
      pooling_api: http://vmpooler.delivery.puppetlabs.net/
    


Vagrant file (Ubuntu 14 master and agent):

    ---
    HOSTS:
      ubuntu1404-64-1:
        pe_dir: 
        pe_ver: 
        pe_upgrade_dir: 
        pe_upgrade_ver: 
        platform: ubuntu-14.04-amd64
        hypervisor: vagrant
        roles:
        - agent
        - master
        - database
        - dashboard
        - classifier
        - default
      ubuntu1404-64-2:
        pe_dir: 
        pe_ver: 
        pe_upgrade_dir: 
        pe_upgrade_ver: 
        platform: ubuntu-14.04-amd64
        hypervisor: vagrant
        roles:
        - agent
        - frictionless
    CONFIG:
      nfs_server: none
      consoleport: 443
      box_url: https://vagrantcloud.com/puppetlabs/boxes/ubuntu-14.04-64-nocm
      box: puppetlabs/ubuntu-14.04-64-nocm


For more info on host generation and what these configs represent see:

* [Creating A Test Environment](creating_a_test_environment.md)


### gen_pre_suite

To run:

    rake beaker_quickstart:gen_pre_suite
    
This task will generate a default Beaker pre-suite file.

The gen_pre-suite task will create a file 'default_pre_suite.rb' in acceptance/setup.

If the file already exists, it will not be overwritten. This will allow you to edit the pre_suite file yourself if required.

pre_suite file:

    install_puppet
  
See the other tutorial docs in this directory for more information on pre-suites:

* [Test Suites](test_suites.md)


### gen_smoke_test

To run:

    rake beaker_quickstart:gen_smoke_test
    
This task will generate a default Beaker smoke test file.

The gen_smoke_test task will create a file 'default_smoke_test.rb' in acceptance/tests.

If the file already exists, it will not be overwritten. This will allow you to edit the test file yourself if required.

smoke test file:

    test_name 'puppet install smoketest'
    step 'puppet install smoketest: verify \'puppet help\' can be successfully called on
    all hosts'
        hosts.each do |host|
          on host, puppet('help')
        end
  
This smoke test will check that Puppet has been successfully installed on the hosts.

For more information on the Beaker dsl methods available to you in your tests see:

- [Beaker dsl](how_to/the_beaker_dsl.md)


### run_test

To run:
  
    rake beaker_quickstart:run_test
    
This task will run the above 3 tasks in sequential order and then execute a Beaker test run using all 3 files.

    beaker --hosts acceptance/config/default_vmpooler_hosts.yaml --pre-suite acceptance/setup/default_pre_suite.rb --tests 
    acceptance/tests/default_smoke_test.rb

You will end up with provisioned hosts, with puppet installed and a test check executed to make sure that puppet was indeed installed.

For more information on running Beaker tests see:

* [Test run](test_run.md)
 

