set -e

. local_setup.sh

rm -f /tmp/hello.world.$$.txt

puppet apply <<PP | grep "defined content as '{md5}098f6bcd4621d373cade4e832627b4f6'"
file{ "/tmp/hello.world.$$.txt":
        content => "test",
}
PP

[ -f /tmp/hello.world.$$.txt ]
