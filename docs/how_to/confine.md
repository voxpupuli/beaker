# Confine

## How does it work?

The confine method will limit the hosts the testcase is run against. You can pass in either :to or :except
to control how the criteria is applied (**:to** will apply the criteria to the hosts in order to find a match,
**:except** will apply the criteria to the hosts, and return those hosts that do not match). The default behaviour
is that the **TestCase#hosts** array is modified to only contain the hosts that match (or don't match) the criteria.

Full method documentation here:

* [confine](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#confine-instance_method) 

## How does the optional Array<Host> parameter work?

However, if you pass in the optional Array<Host> to the method, the criteria will be applied to this hosts array
(not **TestCase#hosts**). Subsequently, any of the hosts contained in **TestCase#hosts** that were not included in the Array<Host>
passed to the method, will remain in **TestCase#hosts**. But any hosts that were filtered out by the criteria match 
will be overwritten.

Take the following example:

    HOSTS:
      ubuntu_master:
        roles:
        - master
        - database
        - dashboard
        - classifier
        platform: ubuntu-14.04-amd64
        hypervisor: vcloud
        template: Delivery/Quality Assurance/Templates/vCloud/ubuntu-1404-x86_64
      centos7_agent:
        roles:
        - agent
        - frictionless
        platform: el-7-x86_64
        template: Delivery/Quality Assurance/Templates/vCloud/centos-7-x86_64
        hypervisor: vcloud
      ubuntu_agent:
        roles:
        - agent
        - frictionless
        platform: ubuntu-14.04-amd64
        template: Delivery/Quality Assurance/Templates/vCloud/ubuntu-1404-x86_64
        hypervisor: vcloud


Using the following confine:

`confine :to, { :platform => 'el-7-x86_64' }, agents`

We will end up with a **TestCase#hosts** array with two hosts, one agent and one master.

Since we passed in the 'agents' host array to the method, the criteria (:platform => 'el-7-x86_64') will be applied
to this set of hosts. Only one agent matches this criteria (centos7_agent). Since the master host (ubuntu_master) was not
included in the 'agents' host array when the criteria match was performed, it will remain in **TestCase#hosts**. But only one agent
remains after the criteria match.

`confine :except, { :platform => 'el-7-x86_64' }, agents`

Will also return two hosts, one agent and one master. But it will be the other agent (ubuntu_agent) as its platform does not match
'el-7-x86_64'.

`confine :to, { :platform => 'el-7-x86_64' }`

Will return one host (centos7_agent). Because no Array<Host> was passed to the confine method, the criteria match
is being applied directly to **TestCase#hosts** (which contains all hosts).

`confine :except, { :platform => 'el-7-x86_64' }`

Will return two hosts (ubuntu_master and ubuntu_agent). 

In order to limit the hosts to only the ubuntu agent, you would need to use:

`confine :to, { :platform => 'ubuntu-14.04-amd64', :role => 'agent' }`