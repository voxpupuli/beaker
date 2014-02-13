# Beaker #
Beaker is a test harness capable of provisioning new Systems Under Test (SUTs) as defined in a configuration file.

## System Under Test (SUT)... ##
  - may be physical, virtual; local or remote.
  - will need a properly configured network and DNS or hosts file.
  - must configure pass through ssh auth for the root user.
  - must have the `ntpdate` binary installed
  - must have the `curl` binary installed
  - **Windows:** Cygwin must be installed (with `curl`, `sshd`, `bash`) and the necessary
    Windows gems (sys-admin, win32-dir, etc).
  - **FOSS install**: you must have `git`, `ruby`, `rdoc` installed
  - **PE install**: PE will install `git`, `ruby`, `rdoc`.

# Install it! (FOSS Installation) #
Installation is easy! The difficult question is whether to install as a gem or through `git`.

## Pre-requisites ##
1. `ruby` >= 1.8.7

## As a gem ##
    gem install beaker

## From git ##
First, clone the repository from GitHub:

    git clone https://github.com/puppetlabs/beaker.git
    cd beaker

Next, install the supporting libraries through [Bundler](http://bundler.io/) or [RubyGems](http://rubygems.org/).

### Bundler ###
    bundle install

### RubyGems ###
    gem install rubygems net-ssh net-scp systemu

# Configure it! #
Beaker requires a host configuration file, written in `YAML`,  to run tests. This file states the type of installation and configuration to use, especially for PE.

## Example Test Configuration File ##
Let's jump right to an example configuration.

    HOSTS:
      ubuntu-1004-64:
        roles:
          - master
          - agent
          - dashboard
        platform: ubuntu-10.04-amd64
        hypervisor: fusion
        snapshot: clean
      ubuntu-1004-32:
        roles:
          - agent
        platform: ubuntu-10.04-i386
        hypervisor: fusion
        snaphost: clean
    CONFIG:
      consoleport: 443

* Here we have the host *ubuntu-1004-64*. It is a 64-bit Ubuntu box, serving as Puppet Master,
Puppet Dashboard, and Puppet Agent. 
* The host *ubuntu-1004-32* is a 32-bit Ubunutu node and will be a 
Puppet Agent only.  
* The Dashboard will be configured to run HTTPS on port 443.

You can configure a very different test scenario by re-arranging the `roles`:

    HOSTS:
      ubuntu-1004-64:
        roles:
          - dashboard
          - agent
        platform: ubuntu-10.04-amd64
        hypervisor: fusion
        snapshot: clean
      ubuntu-1004-32:
        roles:
          - master
          - agent
        platform: ubuntu-10.04-i386
        hypervisor: fusion
        snapshot: clean
    CONFIG:
      consoleport: 443

* The host *ubuntu-1004-32* is now the Puppet Master and Puppet Agent.
* The host *ubuntu-1004-64* still runs Puppet Dashboard and Puppet Agent. 
* The result is a split Master/Dashboard install.  Beaker will automagically prepare an appropriate answers file for use with the PE Installer.

### Required Host Settings ###
To properly define a host you must provide:

* `name`: The string identifying this host
* `platform`: One of the Beaker supported platforms

### Optional Host Settings ###
Additionaly, Beaker supports the following host options:

* `ip`: IP address of the SUT
* `hypervisor`: the hypervisor to use for host deployment
    * one of `solaris`, `blimpy`, `vsphere`, `fusion`, `aix`, `vcloud` or `vagrant`
    * additional settings may be required depending on the selected hypervisor (ie, `template`, `box`, `box_url`, etc).  Check the documentation below for your hypervisor for details  
* `snapshot`: the name of the snapshot to revert to before testing
* `roles`: the 'job' of this host, an array of `master`, `agent`, `frictionless`, `dashboard`, `database`, `default` or any user-defined string
* `pe_dir`: the directory where PE builds are located, may be local directory or a URL
* `pe_ver`: the version number of PE to install

### Supported Platforms ###
Beaker depends upon each host in the configuration file having a platform type that is correctly formatted and supported.  The platform is used to determine how various operations are carried out internally (such as installing packages using the correct package manager for the given operating system).

The platform's format is `/^OSFAMILY-VERSION-ARCH.*$/` where `OSFAMILY` is one of:

*  AIX
	*  aix
* Linux
	* centos, debian, el, fedora, oracle, redhat, scientific, sles, ubuntu
* Solaris
	* solaris
* Windows
	* windows

`VERSION`'s format is not enforced, but should reflect the `OSFAMILY` selected (ie, ubuntu-1204-i386-master, scientific-6-i386-agent, etc).  `ARCH`'s format is also not enforced, but should be appropriate to the `OSFAMILY` selected (ie, ubuntu-1204-i386-master, sles-11-x86_64-master, debian-7-amd64-master, etc).

## Provisioning ##
Beaker has built in capabilites for managing VMs and provisioning SUTs:

  * VMWare vSphere via the `rbvmomi` gem
  * VMWare Fusion via the `fission` gem
  * EC2 via `blimpy`
  * Solaris zones via SSHing to the global zone
  * Vagrant 

You may mix and match hypervisors as needed.   Hypervisors and snapshot names are defined per-host in the node configuration file.

### Example ###
	lucid-alpha:
	  roles:
	    - master
	    - agent
	  platform: ubuntu-10.04-i386
	  hypervisor: fusion
	  snapshot: foss
	shared-host-in-the-cloud:
	  roles:
	    - agent
	  platform: ubuntu-10.04-i386
	  hypervisor: vsphere
	  snaphost: base

### Keeping Hosts Around ###
Default behavior for Vagrant, vSphere and EC2 is to powerdown/terminate test instances on a successful run. This can be altered with the `--preserve-hosts` option. 

Before each test execution, Beaker will teardown and rebuild the defined SUTs. Use `--no-provision` to skip this behavior.

## VMWare Fusion Support ##
Beaker supports VMware Fusion through the `fission` gem.

### Pre-requisites ###
1. `fission` gem installed and configured, including a `~/.fissionrc` that points to the `vmrun` executable and where virtual machines can be found.

#### Example `.fissionrc` file (it's YAML) ####
    vm_dir: "/Directory/containing/my/.vmwarevm/files/"
    vmrun_bin: "/Applications/VMware Fusion.app/Contents/Library/vmrun"

You can then use the following arguments in the node configuration:

- `hypervisor: fusion` tells us to enable this feature for this host. This is required.
- `snapshot: <name>`, where <name> is the snapshot name to revert to.  This is required.

We'll try and match up the hostname with a VM of the same name. Note that the VM is expected to be pre-configured for running acceptance tests; it should have all the right prerequisite libraries, password-less SSH access for root, etc.

There are a few additional options available in your configuration file. Each host
section can now use:

- `vmname`: This is useful if the hostname of the VM doesn't match the name of
  the `.vmwarevm` file on disk. The alias should be something fission can load.

### Example Fusion Configuration ###
    HOSTS:
      pe-debian6:
        roles:
          - master
          - agent
        platform: debian-6-i386
        vmname: super-awesome-vm-name
        hypervisor: fusion
        snapshot: acceptance-testing-5

### Diagnostics ###
When using `hypervisor fusion`, we'll log all the available VM names and for each
host we'll log all the available snapshot names.

## EC2 Support  ##
Beaker supports EC2 support through the [blimpy](https://rubygems.org/gems/blimpy) gem.

### Pre-requisites ### 
1. `blimpy` gem 
2. `.fog` file correctly configured with your credentials.

### Supported AMIs ###
Currently, there is limited support for EC2 nodes; we are adding support for new platforms shortly. AMIs are built for PE-based installs on:

* Enterprize Linux 6, 64 and 32 bit
* Enterprize Linux 5, 32 bit
* Ubuntu 10.04, 32 bit

Beaker will automagically provision EC2 nodes, provided the `platform` section of your config file lists a supported platform type: ubuntu-10.04-i386, el-6-x86_64, el-6-i386, el-5-i386.

## Solaris Support ##
Used with `hypervisor: solaris`, the harness can connect to a Solaris host via SSH and revert zone snapshots.

### Example `.fog` File ###
    :default:
      :solaris_hypervisor_server: solaris.example.com
      :solaris_hypervisor_username: harness
      :solaris_hypervisor_keyfile: /home/jenkins/.ssh/id_rsa-harness
      :solaris_hypervisor_vmpath: rpool/zoneds
      :solaris_hypervisor_snappaths:
        - rpool/ROOT/solaris

## vSphere Support ##
Beaker can also VMs and snapshots that live within vSphere. To do this create a `~/.fog` file with your vSphere credentials.

### Example `.fog` File ###
    :default:
      :vsphere_server: 'vsphere.example.com'
      :vsphere_username: 'joe'
      :vsphere_password: 'MyP@$$w0rd'

These follow the conventions used by Cloud Provisioner and Fog.

There are two possible `hypervisor` types to use for vSphere testing: `vsphere` and `vcloud`.

### Hypervisor: `vsphere` ###
This option locates an existing static VM, optionally reverts it to a pre-existing snapshot, and runs tests on it.

### Hypervisor: `vcloud` ###
This option clones a new VM from a pre-existing template, runs tests on the newly-provisioned clone, then deletes the clone once testing completes.

This option requires a modified test configuration file that includes the target template as well as three additional parameters in the `CONFIG` section:

1. `datastore`
1. `resourcepool`
1. `folder`

#### Example `vcloud` Config ####
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

## Vagrant Support ##
The option allows for testing against local Vagrant boxes.  

### Pre-requisites ###
1. [Vagrant package](http://downloads.vagrantup.com/) (greather than 1.1) needs to installed

### Configuration ###
The VM is identified by `box` or `box_url` in the config file.  No snapshot name is required as the VM is reverted back to original state post testing using `vagrant destroy --force`.

#### Example Vagrant Config ####
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

VagrantFiles are created per host configuration file.  They can be found in the `.vagrant/beaker_vagrant_files` directory of the current working directory in a subdirectory named after the host configuration file.

    > beaker --hosts sample.cfg
    > cd .vagrant/beaker_vagrant_files; ls
    sample.cfg
    > cd sample.cfg; ls
    VagrantFile

# Run it! #
Now that things are installed and configured, Beaker can be executed!

## Running FOSS tests ##
Puppet FOSS Acceptance tests are stored in their respective Puppet repository, so
you must check out the tests first, then the harness, as such:

### Checkout the tests
    git://github.com/puppetlabs/puppet.git
    cd puppet
### Checkout the harness
    git clone git://github.com/puppetlabs/beaker.git
    cd beaker
    ln -s ../acceptance acceptance-tests
### Run the tests
    ./beaker.rb -c ci/ci-${platform}.cfg --type git -p origin/2.7rc -f 1.5.8 -t acceptance-tests/tests --no-color --xml --debug --pre-suite setup/git/

## Running PE tests ##
When performing a PE install, Beaker expects to find PE tarballs and a LATEST file in `/opt/enterprise/dists`; the LATEST file indicates the version string of the most recent tarball.

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
    git clone git@github.com:puppetlabs/beaker.git
    cd beaker
### Pre-suite and Post-suite
The harness command line supports `--pre-suite` and `--post-suite`.  `--pre-suite` describes steps to take after initial provisioning/configuring of the VMs under test before the tests are run.  `--post-suite` steps are run directly after tests.

Both options support directories, individual files and comma separated lists of directories and files.  Given a directory it will look for files of the type `*.rb` within that directory.  Steps will be run in the order they appear on the command line.  Directories of steps will be run in alphabetic order of the `*.rb` files within the directory.

    --pre-suite setup/early/mystep.rb,setup/early/mydir    

### Run the tests
    bundle exec beaker.rb -c your_config.cfg --type pe -t test_repo/tests --debug

### Failure management
By default, if a test fails the harness will move on and attempt the next test in the suite.  This may be undesirable when debugging.  The harness supports an optional `--fail-mode` to alter the default behavior on failure:

- `fast`: After first failure, do not test any subsequent tests in the given suite, simply run cleanup steps and then exit gracefully.  This option short circuits test execution while leaving you with a clean test environment for any follow up testing. 
- `slow`: After the first failure, try to continue running subsequent tests.
- `stop` *(deprecated)*: After first failure, do not test any subsequent tests in the given suite, do not run any cleanup steps, and exit immediately. **This mode has been deprecated**; please use `fast` instead.

## Topic Branches, Special Test Repo
    bundle exec beaker.rb -c your_cfg.cfg --debug --type git -p 2.7.x -f 1.5.8 -t path-to-your-tests 

    path-to-test:
    If you are testing on FOSS, the test for each branch can be found in the puppet repo under acceptance/tests

Special topic branch checkout with a targeted test:

    bundle exec beaker.rb -c your_cfg --type git -p https://github.com/SomeDude/puppet/tree/ticket/2.6.next/6856-dangling-symlinks -f 1.5.8 / 

# Extend it!#
You may need to extend the harness DSL to handle your particular test case. Beaker supports this possibility through `--load-path`.

## About `--load-path` ##
`--load-path` allows you to run Beaker with additions to the `LOAD_PATH`. You can specify a single directory or a comma separated list of directories.

    bundle exec beaker.rb --debug --config ubuntu1004-32mda.cfg --tests ../puppet/acceptance/tests/resource/cron/should_allow_changing_parameters.rb  --fail fast --root-keys --type pe --load-path ../puppet/acceptance/lib/ 
