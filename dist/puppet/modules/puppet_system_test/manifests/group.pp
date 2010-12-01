# Class: puppet-testing::group
#
# Actions:
#   Install example groups: [group1,group2,group3]
#
# Sample Usage:
#

class puppet_system_test::group {

  group { puppetgroup1:
    ensure => present,
  }

  group { puppetgroup2:
    gid => 5000,
    ensure => present,
  }

  group { puppetgroup3:
    gid => 500,
    members => [ puppetuser1, puppetuser2 ],
    require => [ User["user1"], User["user2"] ],
  }
    
}
