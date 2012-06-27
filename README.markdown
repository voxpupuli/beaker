# Running the Distributed Test Harness #

## Configuration ##

  Running the system tests requiers at least two hosts: a "Test Driver" and at
  least one (or more) test target systems.
  
  System Under Test
  - You will need at least one System Under Test (SUT) host, physical or virtual.
  - The SUT will need a propery configured network and DNS or hosts file.
  - On the SUT, you must configure pass through ssh auth for the root user.
  - The SUT must have the "ntpdate" binary installed
  - The SUT must have the "curl" binary installed
  - On Windows, Cygwin must be installed (with curl, sshd, bash) and the necessary
    windows gems (sys-admin, win32-dir, etc).
  - FOSS install: you must have git, ruby, rdoc installed on your SUT. 
  - PE install: PE will install git, ruby, rdoc.

  Test Driver
  - The harness need not be ran as root.
  - The Test Driver must have ruby (1.8.7+) installed, including the following ruby gems: 
    rubygems, net-ssh, net-scp, systemu


Prepare a config file.  The test harness is configuration driven; the config file 
is yaml formated.  The manner on installation and configuration will be affected 
by the config file; this is especially true when running PE.

    HOSTS:
      ubuntu-1004-64:
        roles:
          - master
          - agent
          - dashboard
        platform: ubuntu-10.04-amd64
      ubuntu-1004-32:
        roles:
          - agent
        platform: ubuntu-10.04-i386
    CONFIG:
      consoleport: 443


Here we have the machine "ubuntu-1004-64", a 64 bit Ubuntu box, serving as Puppet Master,
Dashboard, and Agent.  The host "ubuntu-1004-32"i, a 32-bit Ubunutu node, will be a 
Puppet Agent only.  The Dashboard will be configured to run HTTPS on port 443.

You can setup a very different test scenario by simply re-arranging the "roles":

    HOSTS:
      ubuntu-1004-64:
        roles:
          - dashboard
          - agent
        platform: ubuntu-10.04-amd64
      ubuntu-1004-32:
        roles:
          - master
          - agent
        platform: ubuntu-10.04-i386
    CONFIG:
      consoleport: 443

A comprehensive list of all supported plaforms and config settings can be found in:
cfg_examples/all-platforms.cfg


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
    ./systest.rb --vmrun soko -c ci/ci-${platform}.cfg --type git -p origin/2.6rc -f 1.5.8 -t acceptance-tests/tests --no-color --xml --debug


## Topic branches, special test repo
    ./systest.rb -c your_cfg --debug --type git -p 2.6.next  -f 1.5.8 -t path-to-your-tests 

path-to-test:
If you are testing on FOSS, the test for each branch can be found in the puppet repo under acceptance/tests

Special topic branch checkout with a targeted test:
    ./systest.rb -c your_cfg --type git -p https://github.com/SomeDude/puppet/tree/ticket/2.6.next/6856-dangling-symlinks -f 1.5.8 -t tests/acceptance/ticket_6856_manage_not_work_with_symlinks.rb


## Running PE tests ##

When performing a PE install, systest expects to find PE tarballs and a LATEST file in /opt/enterprise/dists; the LATEST file
indicated the version string of the most recent tarball.

    $ [topo@gigio ]$ cat /opt/enterprise/dists/LATEST 
    2.0.0
    
    $ [topo@gigio ]$ ls -1 /opt/enterprise/dists
    LATEST
    puppet-enterprise-2.0.0-debian-5-amd64.tar.gz
    puppet-enterprise-2.0.0-debian-5-i386.tar.gz
    puppet-enterprise-2.0.0-debian-6-amd64.tar.gz
    puppet-enterprise-2.0.0-debian-6-i386.tar.gz
    puppet-enterprise-2.0.0-el-4-i386.tar.gz
    puppet-enterprise-2.0.0-el-4-x86_64.tar.gz
    puppet-enterprise-2.0.0-el-5-i386.tar.gz
    puppet-enterprise-2.0.0-el-5-x86_64.tar.gz
    puppet-enterprise-2.0.0-el-6-i386.tar.gz
    puppet-enterprise-2.0.0-el-6-x86_64.tar.gz
    puppet-enterprise-2.0.0-sles-11-i386.tar.gz
    puppet-enterprise-2.0.0-sles-11-x86_64.tar.gz
    puppet-enterprise-2.0.0-solaris-10-i386.tar.gz
    puppet-enterprise-2.0.0-solaris-10-sparc.tar.gz
    puppet-enterprise-2.0.0-ubuntu-10.04-amd64.tar.gz
    puppet-enterprise-2.0.0-ubuntu-10.04-i386.tar.gz

### Checkout your tests
    git clone git@github.com:your/test_repo.git
    cd test_repo
### Checkout the harness
    git clone git@github.com:puppetlabs/puppet-acceptance.git
    cd puppet-acceptance
### Run the tests
    ./systest.rb -c your_config.cfg --type pe -t test_repo/tests --debug

## VMWare Fusion support ##

systest allows VMWare Fusion users to have their virtual machines reverted to a
snapshot prior to running tests.

Additional requirements on the Test Driver:
- Must have a ~/.fissionrc that points to the `vmrun` executable and where VMs
  can be found

An example `.fissionrc` file (it's YAML):

    ---
    vm_dir: "/Directory/containing/my/.VMX/files"
    vmrun_bin: "/Applications/VMware Fusion.app/Contents/Library/vmrun"

You can then use the following arguments to systest:
- `--vmrun fusion` tells us to enable this feature. This is required.
- `--snapshot <name>`, where <name> is the snapshot name to revert to. This
  applies across *all* VMs, so it only makes sense if you want to use the same
  snapshot name for all VMs. This is optional.

We'll try and match up the hostname (from your configuration file) with a VM of
the same name. Note that the VM is expected to be pre-configured for running
acceptance tests; it should have all the right prerequisite libraries,
password-less SSH access for root, etc.

There are a few additional options available in your configuration file. Each host
section can now use:

- `vmname`: This is useful if the hostname of the VM doesn't match the name of
  the .VMX file on disk. The alias should be something fission can load.

- `fission`: A new subsection for fission-specific options, currently limited to:

  - `snapshot`: This is useful if you'd like to use different snapshots for each
    host. The value should be a valid snapshot name for the VM.

Example:

    HOSTS:
      pe-debian6:
        roles:
          - master
          - agent
        platform: debian-6-i386
        vmname: super-awesome-vm-name
        fission:
          snapshot: acceptance-testing-5

Diagnostics:

When using `--vmrun fusion`, we'll log all the available VM names and for each
host we'll log all the available snapshot names.
