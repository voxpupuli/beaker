set -e

. local_setup.sh

$BIN/puppet apply --debug <<PP | tee /tmp/puppet-$$.log
user{ "root":
        ensure => "present",
}
PP

! grep created /tmp/puppet-$$.log
