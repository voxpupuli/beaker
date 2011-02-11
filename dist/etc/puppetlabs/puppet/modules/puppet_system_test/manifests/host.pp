# Class: puppet-testing::host

class puppet_system_test::host {

  host { puppethost1:
     ip => "1.2.3.4",
     name => "puppethost1.name",
     ensure => present,
  }

  host { puppethost2:
     ip => "5.6.7.8",
     host_aliases => "ph2.alias.1",
  }

  host { puppethost3:
     ip => "9.10.11.12",
     host_aliases => [ "ph3.alias.1", "ph3.alias.2" ],
     ensure => present,
  }

}
