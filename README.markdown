# Running the Distributed Test Harness #

## Install the harness on your 'Test Driver' ##
How to install the test harness on your workstation:

  Pre-requisites: Ruby 1.8.7+

  Automagically:

    git clone https://github.com/puppetlabs/puppet-acceptance.git
    bundle install

  Manumatically:

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
      ubuntu-1004-32:
        roles:
          - agent
        platform: ubuntu-10.04-i386
    CONFIG:
      consoleport: 443

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

In this case, the host 'ubuntu-1004-32' is now the Puppet Master, while 'ubuntu-1004-64' is the
Puppet Dashboard host, resulting in a split Master/Dashboard install.  Systest will automagically 
prepare an appropriate answers file for use with the PE Installer.


## Provisioning ##
Systest has built in capabilites for managing VMs and provisioning SUTs:

  VMWare vSphere 
  VMWare Fusion
  EC2 via blimpy

# VMWare Fusion support #
Pre-requisite: Fission gem installed and configured, including a ~/.fissionrc 
that points to the `vmrun` executable and where VMs can be found.
  Example `.fissionrc` file (it's YAML):
    ---
    vm_dir: "/Directory/containing/my/.VMX/files"
    vmrun_bin: "/Applications/VMware Fusion.app/Contents/Library/vmrun"

You can then use the following arguments to Systest:
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

# EC2 Support #
Pre-requisite: Blimpy gem installed and .fog file correctly configured with your credentials.

--vmrun blimpy

Currently, there is limited support EC2 nodes; we are adding support for new platforms shortly.

AMIs are built for PE based installs on:
  - Enterprize Linux 6, 64 and 32 bit
  - Enterprize Linux 5, 32 bit
  - Ubuntu 10.04, 32 bit

Systest will automagically provision EC2 nodes, provided the 'platform:' section of your config file
lists a supported platform type: ubuntu-10.04-i386, el-6-x86_64, el-6-i386, el-5-i386.


## Putting it all together ##

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
    ./systest.rb --vmrun fusion -c ci/ci-${platform}.cfg --type git -p origin/2.7rc -f 1.5.8 -t acceptance-tests/tests --no-color --xml --debug


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

### Checkout your tests
    git clone git@github.com:your/test_repo.git
    cd test_repo
### Checkout the harness
    git clone git@github.com:puppetlabs/puppet-acceptance.git
    cd puppet-acceptance
### Run the tests
    ./systest.rb -c your_config.cfg --type pe -t test_repo/tests --debug

## Topic branches, special test repo
    ./systest.rb -c your_cfg.cfg --debug --type git -p 2.7.x -f 1.5.8 -t path-to-your-tests 

    path-to-test:
    If you are testing on FOSS, the test for each branch can be found in the puppet repo under acceptance/tests

Special topic branch checkout with a targeted test:
    ./systest.rb -c your_cfg --type git -p https://github.com/SomeDude/puppet/tree/ticket/2.6.next/6856-dangling-symlinks -f 1.5.8 / 
     -t tests/acceptance/ticket_6856_manage_not_work_with_symlinks.rb
