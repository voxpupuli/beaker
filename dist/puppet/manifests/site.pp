file { "/root/file_0":
    mode => 440,
    owner => root,
    group => root,
    source => "puppet:///modules/file_serve/file_0"
}

file { "/root/file_1":
    mode => 440,
    owner => root,
    group => root,
    source => "puppet:///modules/file_serve/file_1"
}

file { "/root/file_100":
    mode => 440,
    owner => root,
    group => root,
    source => "puppet:///modules/file_serve/file_100"
}

#file { "/root/file_100000":
#    mode => 440,
#    owner => root,
#    group => root,
#    source => "puppet:///modules/file_serve/file_100000"
#}

file { "/root/many_files/":
    recurse => true,
    purge => true,
    force => true,
    mode => 750,
    owner => root,
    group => root,
    source => "puppet:///modules/file_serve/many_files/"
}
