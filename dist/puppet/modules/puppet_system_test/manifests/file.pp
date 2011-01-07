# Class: puppet-testing::file
#
# Actions:
#   Install example file resources: [file_0, file_1, file_100]
#   Install example dir resource: [many_files/*]
#
# Sample Usage:

class puppet_system_test::file {

  file { "/root/file_0":
				mode => 440,
				owner => root,
				group => root,
				source => "puppet:///modules/puppet_system_test/file_0"
  }

  file { "/root/file_1":
				mode => 440,
				owner => root,
				group => root,
				source => "puppet:///modules/puppet_system_test/file_1"
  }

  file { "/root/file_100":
				mode => 440,
				owner => root,
				group => root,
				source => "puppet:///modules/puppet_system_test/file_100"
  }

  file { "/root/many_files/":
				recurse => true,
				purge => true,
				force => true,
				mode => 750,
				owner => root,
				group => root,
				source => "puppet:///modules/puppet_system_test/many_files/"
  }
}
