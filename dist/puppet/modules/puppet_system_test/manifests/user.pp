# Class: puppet-testing::file
#
# Actions:
#
# Sample Usage:

#  user { user1:
#    comment => "User 1",
#    ensure => present,
#  }
#
#  user { user2:
#    gid => 5000,
#    comment => "User 2".
#    groups => [ bin, adm ],
#    ensure => present,
#  }
#
#  user { user3:
#    gid => 500,
#    comment => "User 3",
#    shell => "/bin/sh",
#    uid => 3333,
#    ensure => present,
#  }


class puppet_system_test::user {

  user { puppetuser1:
    comment => "PuppetTestUser 1",
    ensure => present,
  }

  user { puppetuser2:
    gid => 5000,
    comment => "PuppetTestUser 2",
    ensure => present,
  }

  user { puppetuser3:
    gid => 500,
    comment => "PuppetTestUser 3",
    shell => "/bin/sh",
    uid => 3333,
    ensure => present,
  }

}
