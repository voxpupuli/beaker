file { "/root/zd_file":
    mode => 440,
    owner => root,
    group => root,
    source => "puppet:///modules/file_serve/zd_file"
}

file { "/root/sm_file":
    mode => 440,
    owner => root,
    group => root,
    source => "puppet:///modules/file_serve/sm_file"
}

file { "/root/md_file":
    mode => 440,
    owner => root,
    group => root,
    source => "puppet:///modules/file_serve/md_file"
}

file { "/root/lg_file":
    mode => 440,
    owner => root,
    group => root,
    source => "puppet:///modules/file_serve/lg_file"
}

file { "/root/many_files/":
    recurse => true,
    purge => true,
    force => true,
    mode => 750,
    owner => root,
    group => root,
    source => "puppet:///modules/file_serve/many_files/"
}
