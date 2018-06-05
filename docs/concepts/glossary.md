# Glossary

Most terms used in Beaker documentation should be common. The following documents project jargon which may otherwise be confusing.

## Coordinator

The Coordinator is the system on which Beaker itself is run. In many environments this will be a local host, typically a developer's primary machine. Used instead of [Master](#master) to avoid confusion.

## Hypervisor

The Hypervisor component manages the hypervisor adapters that connect to hypervisor systems (e.g. ESXi, Cisco, VMPooler) that provide SUTs.

## Master

A SUT running as a Puppet Master.

## SUT

(See [System Under Test](#system-under-test).)

## System Under Test

A System Under Test (SUT) is one of the systems which is the subject of testing with Beaker. Contrast the [Beaker Coordinator](#coordinator).
