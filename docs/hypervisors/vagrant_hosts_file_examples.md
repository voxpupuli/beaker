#centos-511-x64.yml
```
HOSTS:
  centos-511-x64:
    roles:
      - master
    platform: el-5-x86_64
    box: puppetlabs/centos-5.11-64-nocm
    hypervisor: vagrant
```
#centos-65-x64.yml
```
HOSTS:
  centos-65-x64:
    roles:
      - master
    platform: el-6-x86_64
    box: puppetlabs/centos-6.5-64-nocm
    hypervisor: vagrant
```
#debian-609-x64.yml
```
HOSTS:
  debian-609-x64:
    roles:
      - master
    platform: debian-6-amd64
    box: puppetlabs/debian-6.0.9-64-nocm
    hypervisor: vagrant
```
#debian-78-x64.yml
```
HOSTS:
  debian-78-x64:
    roles:
      - master
    platform: debian-7-amd64
    box: puppetlabs/debian-7.8-64-nocm
    hypervisor: vagrant
```
#ubuntu-server-1204-x64.yml
```
HOSTS:
  ubuntu-server-1204-x64:
    roles:
      - master
    platform: ubuntu-1204-amd64
    box: puppetlabs/ubuntu-12.04-64-nocm
    hypervisor: vagrant
```
#ubuntu-server-1404-x64.yml
```
HOSTS:
  ubuntu-server-1404-x64:
    roles:
      - master
    platform: ubuntu-14.04-amd64
    box: puppetlabs/ubuntu-14.04-64-nocm
    hypervisor: vagrant
```
