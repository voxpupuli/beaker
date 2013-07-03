# Running the Distributed Test Harness #

## Install the harness on your 'Test Driver' ##
How to install the test harness on your workstation:

  Pre-requisites: Ruby 1.8.7+

  Automagically:

    git clone https://github.com/puppetlabs/puppet-acceptance.git
    bundle install

  Manually:

    git clone https://github.com/puppetlabs/puppet-acceptance.git
    gem install rubygems net-ssh net-scp systemu


## Configure Systems Under Test ##
Running Systest requires at least one 'System Under Test' (SUT) upon which to run tests.

  System Under Test
  - SUT may be physical, virtual; local or remote.
  - The SUT will need a properly configured network and DNS or hosts file.
  - On the SUT, you must configure pass through ssh auth for the root user.
  - The SUT must have the "ntpdate" binary installed
  - The SUT must have the "curl" binary installed
  - On Windows, Cygwin must be installed (with curl, sshd, bash) and the necessary
    windows gems (sys-admin, win32-dir, etc).
  - FOSS install: you must have git, ruby, rdoc installed on your SUT. 
  - PE install: PE will install git, ruby, rdoc.


## Prepare a Test Configuration File ##
  - The test harness is configuration driven
  - The config file is yaml formatted
  - The type of insallation and configuration is dictated by the config file, especialy for PE

Here we have the host 'ubuntu-1004-64', a 64 bit Ubuntu box, serving as Puppet Master,
Dashboard, and Agent; the host "ubuntu-1004-32", a 32-bit Ubunutu node, will be a 
Puppet Agent only.  The Dashboard will be configured to run HTTPS on port 443.

    HOSTS:
      ubuntu-1004-64:
        roles:
          - master
          - agent
          - dashboard
        platform: ubuntu-10.04-amd64
        hypervisor : fusion
        snapshot : clean
      ubuntu-1004-32:
        roles:
          - agent
        platform: ubuntu-10.04-i386
        hypervisor : fusion
        snaphost : clean
    CONFIG:
      consoleport: 443

You can setup a very different test scenario by simply re-arranging the "roles":

    HOSTS:
      ubuntu-1004-64:
        roles:
          - dashboard
          - agent
        platform: ubuntu-10.04-amd64
        hypervisor : fusion
        snapshot : clean
      ubuntu-1004-32:
        roles:
          - master
          - agent
        platform: ubuntu-10.04-i386
        hypervisor : fusion
        snapshot : clean
    CONFIG:
      consoleport: 443

In this case, the host 'ubuntu-1004-32' is now the Puppet Master, while 'ubuntu-1004-64' is the
Puppet Dashboard host, resulting in a split Master/Dashboard install.  Systest will automagically 
prepare an appropriate answers file for use with the PE Installer.


# Provisioning #
Systest has built in capabilites for managing VMs and provisioning SUTs:

  * VMWare vSphere via the RbVmomi gem
  * VMWare Fusion via the Fission gem
  * EC2 via blimpy
  * Solaris zones via SSHing to the global zone
  * Vagrant 

You may mix and match hypervisors as needed.   Hypervisors and snapshot names are defined per-host in the node configuration file.  Default behavior for Vagrant, vSphere and EC2 is to powerdown/terminate test instances on a successful run. This can be altered with the `--preserve-hosts` option.
`--provision` indicates that you want to provision and revert VMs to snapshot before test execution, defaults to true.  Use `--no-provision` to skip provisioning and reverting before test execution.


For example:


    $ cat configs/my_hosts.yml
    lucid-alpha:
      roles:
        - master
        - agent
      platform: ubuntu-10.04-i386
      hypervisor: fusion
      snapshot: foss
      provision: false
    shared-host-in-the-cloud:
      roles:
        - agent
      platform: ubuntu-10.04-i386
      hypervisor: vsphere
      snaphost: base

    $ ./systest.rb --config configs/my_hosts.yml  ....


## VMWare Fusion support ##
Pre-requisite: Fission gem installed and configured, including a ~/.fissionrc 
that points to the `vmrun` executable and where VMs can be found.
  Example `.fissionrc` file (it's YAML):
    ---
    vm_dir: "/Directory/containing/my/.VMX/files"
    vmrun_bin: "/Applications/VMware Fusion.app/Contents/Library/vmrun"

You can then use the following arguments in the node configuration:
- `hypervisor : fusion` tells us to enable this feature for this host. This is required.
- `snapshot : <name>`, where <name> is the snapshot name to revert to.  This is required.

We'll try and match up the hostname with a VM of the same name. Note that the VM is expected to be pre-configured for running acceptance tests; it should have all the right prerequisite libraries, password-less SSH access for root, etc.

There are a few additional options available in your configuration file. Each host
section can now use:

- `vmname`: This is useful if the hostname of the VM doesn't match the name of
  the .VMX file on disk. The alias should be something fission can load.


Example:

    HOSTS:
      pe-debian6:
        roles:
          - master
          - agent
        platform: debian-6-i386
        vmname: super-awesome-vm-name
        hypervisor: fusion
        snapshot: acceptance-testing-5

Diagnostics:

When using `hypervisor fusion`, we'll log all the available VM names and for each
host we'll log all the available snapshot names.

## EC2 Support ##
Pre-requisite: Blimpy gem installed and .fog file correctly configured with your credentials.

hypervisor : blimpy

Currently, there is limited support EC2 nodes; we are adding support for new platforms shortly.

AMIs are built for PE based installs on:
  - Enterprize Linux 6, 64 and 32 bit
  - Enterprize Linux 5, 32 bit
  - Ubuntu 10.04, 32 bit

Systest will automagically provision EC2 nodes, provided the 'platform:' section of your config file lists a supported platform type: ubuntu-10.04-i386, el-6-x86_64, el-6-i386, el-5-i386.

## Solaris Support ##

Used with `hypervisor : solaris`, the harness can connect to a Solaris host via SSH and revert zone snapshots.

Example .fog file:

    :default:
      :solaris_hypervisor_server: solaris.example.com
      :solaris_hypervisor_username: harness
      :solaris_hypervisor_keyfile: /home/jenkins/.ssh/id_rsa-harness
      :solaris_hypervisor_vmpath: rpool/zoneds
      :solaris_hypervisor_snappaths:
        - rpool/ROOT/solaris

## vSphere Support ##

The harness can use vms and snapshots that live within vSphere as well.
To do this create a `~/.fog` file with your vSphere credentials:

Example:

    :default:
      :vsphere_server: 'vsphere.example.com'
      :vsphere_username: 'joe'
      :vsphere_password: 'MyP@$$w0rd'


These follow the conventions used by Cloud Provisioner and Fog.

There are two possible `hypervisor` hypervisor-types to use for vSphere testing, `vsphere` and `vcloud`.

### `hypervisor : vsphere`
This option locates an existing static VM, optionally reverts it to a pre-existing snapshot, and runs tests on it.

### `hypervisor : vcloud`
This option clones a new VM from a pre-existing template, runs tests on the newly-provisioned clone, then deletes the clone once testing completes.

The `vcloud` option requires a slightly-modified test configuration file, specifying both the target template as well as three additional parameters in the 'CONFIG' section ('datastore', 'resourcepool', and 'folder').

    HOSTS:
      master-vm:
        roles:
          - master
          - agent
          - dashboard
        platform: ubuntu-10.04-amd64
        template: ubuntu-1004-x86_64
        hypervisor: vcloud
      agent-vm:
        roles:
          - agent
        platform: ubuntu-10.04-i386
        template: ubuntu-1004-i386
        hypervisor: vcloud
    CONFIG:
      consoleport: 443
      datastore: instance0
      resourcepool: Delivery/Quality Assurance/FOSS/Dynamic
      folder: delivery/Quality Assurance/FOSS/Dynamic


## Vagrant support ##
The option allows for testing against local Vagrant boxes.  The vm is identified by `box` or `box_url` in the config file.  No snapshot name is required as the vm is reverted back to original state post testing using `vagrant destroy --force`.

    HOSTS:
      ubuntu-10-04-4-x64:
        roles:
          - master
          - agent
          - dashboard
          - cloudpro
        platform: ubuntu-10.04.4-x64
        hypervisor: vagrant
        box: ubuntu-server-10044-x64-vbox4210
        box_url: http://puppet-vagrant-boxes.puppetlabs.com/ubuntu-server-10044-x64-vbox4210.box
    CONFIG:
      nfs_server: none
      consoleport: 443

# Putting it all together #

## Running FOSS tests ##
Puppet FOSS Acceptance tests are stored in their respective Puppet repository, so
you must check out the tests first, then the harness, as such:

### Checkout the tests
    git://github.com/puppetlabs/puppet.git
    cd puppet
### Checkout the harness
    git clone git://github.com/puppetlabs/puppet-acceptance.git
    cd puppet-acceptance
    ln -s ../acceptance acceptance-tests
### Run the tests
    ./systest.rb -c ci/ci-${platform}.cfg --type git -p origin/2.7rc -f 1.5.8 -t acceptance-tests/tests --no-color --xml --debug --pre-suite setup/git/


## Running PE tests ##

When performing a PE install, Systest expects to find PE tarballs and a LATEST file in /opt/enterprise/dists; the LATEST file
indicates the version string of the most recent tarball.

    $ [topo@gigio ]$ cat /opt/enterprise/dists/LATEST 
    2.5.3
    
    $ [topo@gigio ]$ ls -1 /opt/enterprise/dists
    LATEST
    puppet-enterprise-2.5.3-debian-6-amd64.tar.gz
    <snip>
    puppet-enterprise-2.5.3-ubuntu-12.04-i386.tar.gz

You can also install from git.  Use the `--install` option, which can install puppet along with other infrastructure.  This option supports the following URI formats:

- `PATH`: A full and complete path to a git repository

    	  --install git://github.com/puppetlabs/puppet#stable

- `KEYWORD/name`:  The name of the branch of KEYWORD git repository.  Supported keywords are `PUPPET`, `FACTER`, `HIERA` and `HIERA-PUPPET`. 

    	  --install PUPPET/3.1.0

### Checkout your tests
    git clone git@github.com:your/test_repo.git
    cd test_repo
### Checkout the harness
    git clone git@github.com:puppetlabs/puppet-acceptance.git
    cd puppet-acceptance
### Pre-suite and Post-suite
The harness command line supports `--pre-suite` and `--post-suite`.  `--pre-suite` describes steps to take after initial provisioning/configuring of the vms under test before the tests are run.  `--post-suite` steps are run directly after tests.

Both options support directories, individual files and comma separated lists of directories and files.  Given a directory it will look for files of the type `*.rb` within that directory.  Steps will be run in the order they appear in on the command line.  Directories of steps will be run in alphabetic order of the `*.rb` files within the directory.

    --pre-suite setup/early/mystep.rb,setup/early/mydir    
### Run the tests
    ./systest.rb -c your_config.cfg --type pe -t test_repo/tests --debug

### Failure management
By default if a test fails the harness will move on and attempt the next test in the suite.  This may be undesirable when debugging.  The harness supports an optional `--fail-mode` to alter the default behavior on failure:

- `fast`: After first failure do not test any subsequent tests in the given suite, simply run cleanup steps and then exit gracefully.  This option short circuits test execution while leaving you with a clean test environment for any follow up testing. 

- `stop`: After first failure do not test any subsequent tests in the given suite, do not run any cleanup steps, exit immediately.  This is useful while testing setup steps or if you plan to revert the test environment before every test.

## Topic branches, special test repo
    ./systest.rb -c your_cfg.cfg --debug --type git -p 2.7.x -f 1.5.8 -t path-to-your-tests 

    path-to-test:
    If you are testing on FOSS, the test for each branch can be found in the puppet repo under acceptance/tests

Special topic branch checkout with a targeted test:

    ./systest.rb -c your_cfg --type git -p https://github.com/SomeDude/puppet/tree/ticket/2.6.next/6856-dangling-symlinks -f 1.5.8 / 
     -t tests/acceptance/ticket_6856_manage_not_work_with_symlinks.rb
     
     
## Making extensions to the harness using `--load-path`

You may need to extend the harness DSL (data specific language) to handle your particular test case.  To run the harness with an addition to the LOAD_PATH use `--load-path`.  You can specify a single directory or a comma separated list of directories to be added.

    bundle exec ./systest.rb --debug --config ubuntu1004-32mda.cfg --tests ../puppet/acceptance/tests/resource/cron/should_allow_changing_parameters.rb  --fail fast --root-keys --type pe --load-path ../puppet/acceptance/lib/ 
