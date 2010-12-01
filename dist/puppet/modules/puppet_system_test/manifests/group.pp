# Class: puppet_system_test::group

class puppet_system_test::group {

  group { puppetgroup1:
    gid => 5001,
    ensure => present,
  }

  group { puppetgroup2:
    gid => 5002,
    ensure => present,
  }

  group { puppetgroup3:
    gid => 5003,
    members => [ puppetuser1, puppetuser2 ],
  }
}
