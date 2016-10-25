# Amazon Web Services - Elastic Compute Cloud (EC2)

EC2 is a "web service that provides resizable compute capacity in the cloud."

[EC2 site](https://aws.amazon.com/ec2/).

# Getting Started

### Requirements

- Get EC2 access from your IT dept, particularly your `aws_access_key_id` & `aws_secret_access_key`.
- put these values into your [~/.fog file](http://fog.io/about/getting_started.html).

### Setup Amazon Image Config

The Amazon Image Config file in Beaker is the file that specifies which Amazon
Machine Image (AMI) should be used for a host and which EC2 region that host
should be generated into.

The text in this file follows this form:

    AMI:
      <host-vmname-value>:
        :image:
          :<type>: <ami-id>
          :<type>: <ami-id>
        :region: <region-id>
      <host-vmname-value>:
        ...

The `host-vmname-value` is an ID used to reference one of these particular AMI
definitions. It is applied to a host via the `vmname` key in the hosts file.

The `type` variable is an arbitrary key that you can use to specify the different
types of that host platform that you can be testing with. Note that this value
will be grabbed automatically via the value for the host's `snapshot` key.
For example, we tend to use `:pe` and `:foss` for these values.

The `ami-id` variable is the AMI ID as specified by Amazon. You can see the AMI
ID pattern in EC2's
[Find a Linux AMI]
(http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html)
page, particularly in the "using the Images page" section's step 7. For some
examples of AMI IDs, check out their
[Amazon Linux AMI page](https://aws.amazon.com/amazon-linux-ami/).

The `region-id` variable represents the EC2 region ID from AWS. For reference,
checkout EC2's 
[Regions and Availability Zones page]
(http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html).
An example of a region ID is `eu-west-1` for the Ireland data center.

This file is by default located at `config/image_templates/ec2.yaml`. This is a
relative path from Beaker's execution location, and can be overridden using the
`:ec2_yaml` key in a CONFIG section of a host file if required.

### Create a Hosts File to Use

An EC2 hosts file looks like a typical hosts file, except that there are a
number of required properties that need to be added to every host in order for
the AWS hypervisor to provision hosts properly.  They come in this form:

    <hostname>:
      <usual stuff, roles, etc>
      vmname: <host-vmname-value>
      hypervisor: ec2
      snapshot: <type>
      amisize: <ami-size>

The `host-vmname-value` references the ID created in the Amazon Image Config file
above.  If not provided, Beaker will try to name an AMI Config using the host's
platform string.

The `type` references the type variable in the Amazon Image Config file as well,
so this key picks out the particular AMI ID from the set available for this type
of host platform.

The `ami-size` variable refers to
[instance types](https://aws.amazon.com/ec2/instance-types/) by their model name.
Some examples of these values are "m3.large", "c4.xlarge", and "r3.8xlarge". The
default value if this key is not provided used by Beaker is "m1.small".
      
### ec2 VM Hostnames

By default, beaker will set the hostnames of the VMs to the 'Public DNS' hostname supplied by ec2 (and which is normally based on the Public IP address). If your test requires the hosts be named identically to the `<hostname>:` from your beaker hosts file, set `:use_beaker_hostnames: true` in the beaker hosts file.

# AWS Keys

For any particular Beaker run, a new EC2 ssh key with a name of the form

    Beaker-<username>-<sanitized_hostname>-<aws_keyname_modifier>-<readable_timestamp>

will be created at the beginning of the run, & cleaned up at the end of the run.

Everything up to `aws_keyname_modifier` will be the same if run from the same
user on the same machine no matter when it's run. This means that if you're
running from a CI system, all of these values will usually be the same, depending
on your setup.

`aws_keyname_modifier` will by default be a 10 digit random number string.
`readable_timestamp`'s most fine grained unit is nanoseconds. Between the two of
these, every Beaker run will generate a unique ssh key name.

These keys are deleted automatically as a part of the cleanup process at the end
of a Beaker run.

# Zombie Killing

If an EC2 host stays around after a Beaker run, we refer to it as a zombie :).
Normal Beaker execution should not create zombies, but a common use case that
can result in zombies is using the `--preserve-hosts` options.

If you would like to be sure that you're not running up your EC2 bill via any
leftover preserved hosts in your EC2 system, we recommend creating a zombie
killing Beaker job.

To setup a zombie killing job, you'll need a Beaker test that kills all the
zombies (referred to later as `kill.rb`):

    ec2 = AwsSdk.new( [], options )
    ec2.kill_zombies( 0 )

Refer to the
[Rubydoc for the `kill_zombies` method]
(http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/AwsSdk#kill_zombies-instance_method)
to learn more about it's
parameters. Running this should be as simple as this:

    # beaker --tests kill.rb

Note that the second argument is tested as a regex against key names, so you
could use the key pattern described above to wipeout machines that match a
pattern such as "Beaker-johnsmith", and it will catch all keys for the "johnsmith"
user.

### How Do I Find Out My Key Prefix?

In order to find out your key pattern as used by Beaker, just kick off a Beaker
run to generate an EC2 host. When you do this, you should see lines that look
like so:

    aws-sdk: Launch instance
    aws-sdk: Ensure key pair exists, create if not
    [AWS EC2 200 0.142666 0 retries] describe_key_pairs(:filters=>[{:name=>"key-name",:values=>["Beaker-johnsmith-Johns-Ubuntu-2-local"]}])

The values string in that line is what you're looking for.
