# Class: puppet_system_test::user

class puppet_system_test::user {

  user { puppetuser1:
    gid => 5002,
    comment => "PuppetTestUser 1",
    ensure => present,
  }

  user { puppetuser2:
    gid => 5002,
    comment => "PuppetTestUser 2",
    ensure => present,
  }

  user { puppetuser3:
    gid => 5003,
    comment => "PuppetTestUser 3",
    shell => "/bin/sh",
    ensure => present,
  }

}
