# Class: puppet-testing::file
#
# Actions:
#
# Sample Usage:

class puppet_system_test::user {

  user { user1:
    comment => "PuppetTestUser 1",
    ensure => present,
  }

  user { user2:
    comment => "PuppetTestUser 2",
    ensure => present,
  }

  user { user3:
    comment => "PuppetTestUser 3",
    shell => "/bin/sh",
    ensure => present,
  }

}
