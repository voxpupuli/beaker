set -e

. local_setup.sh

! $BIN/puppet apply --debug <<PP | grep 'created'
user{ "root":
        ensure => "present",
}
PP
