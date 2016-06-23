# The Hypervisors Directory

This directory contains docs explaining any peculiarities or details of a particular
hypervisor's implementation.

If you don't see a file here for a hypervisor, then it's either not yet documented
(feel free to help us out here!), or it should conform to our normal hypervisor
assumptions.

# External Hypervisors

There are a number of community-supported hypervisors that have not been added to
Beaker itself. The reason for this is that we're looking to decrease Beaker's
dependency footprint, and hypervisors are one of the places where we can often
increase the load across all Beaker uses to benefit a small group that uses a
particular hypervisor.

In order to offset this, we've made a listing of forks below that support other
hypervisors not included in Beaker. Please check them out if you'd
like to use their hypervisor, hopefully it'll save you from spending time
trying to support a new hypervisor yourself.

| Hypervisor | Fork                                               |
|:----------:|:--------------------------------------------------:|
| LXC        | [Obmondo](https://github.com/Obmondo/beaker) |
