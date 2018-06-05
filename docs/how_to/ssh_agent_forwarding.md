# How to Forward ssh(1) Agent

`ssh(1)` agent forwarding can is activated in the `CONFIG` section of the hosts file:

```yaml
HOSTS:
  ...
CONFIG:
  forward_ssh_agent: true
```

Beaker will then make the ssh agent running on the beaker coordinator available to the Systems Under Test (SUT).  There is a gotcha though: the agent socket file in the SUT is only available to the user who signed in.  If you want to access remote machine resources as another user, you *must* change the socket permission.

A dirty hack is to `chmod -R 777 /tmp/ssh-*` before changing to another user and relying on `$SSH_AUTH_SOCK`.

Example:

```puppet
exec { '/bin/chmod -R 777 /tmp/ssh-*':
} ->
vcsrepo { '/var/www/app':
  provider => 'git',
  source   => 'https://example.com/git/app.git',
  user     => 'deploy'
}
```

## Cross-SUT access

If you need to be able to SSH between SUTs while running Beaker acceptance tests, please refer to the [enabling cross SUT access](enabling_cross_sut_access.md) document
