file { "/root/small_file":
    mode => 440,
    owner => root,
    group => root,
    source => "puppet://modules/file_serve/small_file"
}

file { "/root/med_file":
    mode => 440,
    owner => root,
    group => root,
    source => "puppet://modules/file_serve/med_file"
}

file { "/root/file_checks.sh":
    mode => 750,
    owner => root,
    group => root,
    source => "puppet://modules/file_serve/file_checks.sh"
}

file { "/root/many_files/*":
    mode => 440,
    owner => root,
    group => root,
    source => "puppet://modules/file_serve/many_files/"
}
