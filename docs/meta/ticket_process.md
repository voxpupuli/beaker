This doc is here to explain the lifecycle of a Beaker ticket.  If you have any
questions about the workflow of a Beaker ticket, or the stage that it's in, you
should be able to answer them here.  If not, then please let QE know, and we'll
work to answer your question and update this doc, so that we can do this better
going forward.

Note that a typical Beaker ticket goes through these states. They can sometimes
go in order, but on average, they loop around through the various stages,
can cycle a number of times before becoming resolved, and will sometimes skip
stages as well.

## Administrivia

- Beaker tickets live in the 
[BKR project](https://tickets.puppetlabs.com/issues/?jql=project%20%3D%20BKR)
- Create a [Jira account](http://tickets.puppetlabs.com) to interact with them 

## Pre-Development States

These are the states that a Beaker ticket goes through before it is picked up for
development. Note that this is only for work done by the Beaker team. If there
is something you'd like to contribute to, we would appreciate that you go
through the development states for tracking purposes, but you can skip directly
to the "In Progress" state if you're going to work on a ticket.

### Open

The state for newly filed issues. These have not been triaged, and are
waiting to be looked at by the team.

### Needs Information

The state for blocked issues. These can be blocked by another issue (please link
that issue from the ticket if that's the case), or they can be blocked on info
needed from another party.  If this is the case, please assign the ticket to the
person you need info from to move the ticket forward.

### Accepted

This is the state for when a ticket has been triaged, but hasn't yet been
estimated for work from someone on the Beaker team, or someone ready to
take on the work. Any preliminary information needed to understand the 
ticket (before investigation) should be gathered before this point.

### Ready for Engineering

An accepted ticket that has been estimated should be put into the Ready for
Engineering state. This does not necessarily mean that a ticket has been 
prioritized against other Beaker work, but prioritization should occur by 
the time the issue has been picked up in a sprint.

## Development States

Once you're ready to pick up a ticket & work on it, then it should go through
these states.

### In Progress

This state is set aside for a Beaker contributor to let others know that
they're currently working on a particular issue.

### Ready for Merge

Once a Pull Request (PR) is generated for an issue, the contributor should set
the status to Ready for Merge. We do have a github integration setup, so if 
you've titled your PR correctly (according to our 
[contributor docs](/CONTRIBUTING.md)), 
it will be linked from the JIRA ticket.

In the Beaker project, we leave the assignee as the person who wrote the 
proposed change, so that they know that they have to keep pushing for their
code to be merged.

### Resolved

Once your PR is merged, then you can Resolve your ticket. 

**NOTE** that when you do this, you should set the FixedVersion to

    BKR.next
    
The reason that we do this now and not before is that we use this field to 
autogenerate our release notes.  We want to make sure that we capture only
work that is _in_ the next release, not work that's _intended_ for it.
