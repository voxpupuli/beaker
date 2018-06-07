# Arch Linux

> Arch Linux is an independently developed, i686/x86-64 general-purpose GNU/Linux distribution that strives to provide the latest stable versions of most software by following a rolling-release model. The default installation is a minimal base system, configured by the user to only add what is purposely required.

Source: https://wiki.archlinux.org/index.php/Arch_Linux

# Installation

## Specifying a version to install

> Arch Linux strives to maintain the latest stable release versions of its software as long as systemic package breakage can be reasonably avoided.

Source: https://wiki.archlinux.org/index.php/Arch_Linux

Since Arch is a rolling release, the Puppet version installed by Pacman will always be the latest avaliable release from the upstream.

Because of this, it's not possible to specify a specific version with any of the Puppet install helper methods, and a warning will be shown if it is attempted.

Because the Arch version will always be latest, it will always be Puppet 4+ with the AIO packaging, so it's advised to specify this in the config:

```
CONFIG:
  log_level: verbose
  type: aio
```

## Versioning

Arch doesn't really have the idea of a release version, as it's a rolling update.

For coventions sake, it's advised to put the date of creation of your Arch VM in the name of your SUT, so you know roughly when the VM is cut from:

```
HOSTS:
  archlinux-2016.02.02-amd64:
    roles:
      - master
    platform: archlinux-2016.02.02-amd64
    box: terrywang/archlinux
    box_version: 1.0.0
    hypervisor: vagrant
CONFIG:
  log_level: verbose
  type: aio
```
