Pre-requisite: .fog file correctly configured with your credentials.

hypervisor: ec2

### example .fog file ###
    :default:
      :aws_access_key_id: IMTHEKEYID
      :aws_secret_access_key: IMALONGACCESSKYE

### Basic ec2 hosts file ###
    HOSTS:
      centos-5-64-1:
        roles:
          - master
          - dashboard
          - database
          - agent
        vmname: centos-5-x86-64-west
        platform: el-5-x86_64
        hypervisor: ec2
        amisize: c1.medium
        snapshot: pe
        user: ec2-user
      centos-5-64-1:
        roles:
          - agent
        vmname: centos-5-x86-64-west
        platform: el-5-x86_64
        hypervisor: ec2
        amisize: c1.medium
        snapshot: pe
        user: ec2-user
    CONFIG:
      nfs_server: none
      consoleport: 443

Currently, there is limited support EC2 nodes; we are adding support for new platforms shortly.

AMIs are built for PE based installs on:
  - Enterprise Linux 6, 64 and 32 bit
  - Enterprise Linux 5, 32 bit
  - Ubuntu 10.04, 32 bit

Beaker will automagically provision EC2 nodes, provided the 'platform:' section of your config file lists a supported platform type: ubuntu-10.04-i386, el-6-x86_64, el-6-i386, el-5-i386.

### Supported EC2 Variables ###
These variables can either be set per-host or globally.
####`additional_ports`####
Ports to be opened on the instance, in addition to those opened by Beaker to support Puppet functionality.  Can be a single value or an array.  Example valid values: 1001, [1001], [1001, 1002].

Ports opened by default:
* all hosts have [22, 61613, 8139] opened
* `master` will also have 8140 opened
* `dashboard` will also have [443, 4433, 4435] opened
* `database` will also have [5432, 8080, 8081] opened

####`amisize` ####
The [instance type](https://aws.amazon.com/ec2/instance-types/) - defaults to `m1.small`.  
####`snapshot`####
The snapshot to use for ec2 instance creation.
####`subnet_id`####
If defined the instance will be created in this EC2 subnet.  `vpc_id` must be defined.  Cannot be defined at the same time as `subnet_ids`.
####`subnet_ids`####
If defined the instace will be crated in one of the provided array of EC2 subnets.  `vpc_id` must be defined.  Cannot be defined at the same time as `subnet_id`.
####`vmname`####
Used to look up the pre-defined AMI information in `config/image_templates/ec2.yaml`.  Will default to `platform` if not defined.
#####Example ec2.yaml#####
In this example the `vmname` would be `puppetlabs-centos-5-x86-64-west`.  Looking up the `vmname` in the `ec2.yaml` file provides an AMI ID by type (`pe` or `foss`) and the region.
```
AMI:
  puppetlabs-centos-5-x86-64-west:
    :image:
      :pe: ami-pl-12345
    :region: us-west-2
```
####`volume_size`####
Size of the [EBS Volume](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSVolumes.html) that will be attached to the EC2 instance.
####`vpc_id`####
ID of the [VPC](https://aws.amazon.com/vpc/) to create the instances in.  If not provided will either use the default VPC for the provided region (marked as `isDefault`), otherwise falls back to `nil`.  If subnet information is provided (`subnet_id`/`subnet_ids`) this must be defined.
####`user`####
By default root login is not allowed with Amazon Linux. Setting it to ec2-user will trigger `sshd_config` and `authorized_keys` changes by beaker.
