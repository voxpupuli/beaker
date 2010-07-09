#!/bin/bash

function start_puppet_agent {
        MASTER_PORT=18140
        $BIN/puppet agent --vardir /tmp/puppet-$$-agent-var --confdir /tmp/puppet-$$-agent --rundir /tmp/puppet-$$-agent \
                --no-daemonize --onetime --server localhost --debug --masterport $MASTER_PORT "$@"
}

function start_puppet_master {
        MASTER_PORT=18140
        mkdir -p /tmp/puppet-$$-master/manifests/
        $BIN/puppet master --vardir /tmp/puppet-$$-master-var --confdir /tmp/puppet-$$-master --rundir /tmp/puppet-$$-master \
                --no-daemonize --autosign=true --certname=localhost --masterport $MASTER_PORT "$@" &
        MASTER_PID=$!

        for I in `seq 0 10` ; do
                if lsof -i -n -P | grep '\*:'$MASTER_PORT | grep $MASTER_PID > /dev/null ; then
                        break
                else
                        sleep 1
                fi
        done

}

function stop_puppet_master {
        kill $MASTER_PID
}




function start_puppetd {
        MASTER_PORT=18140
        $BIN/../sbin/puppetd --vardir /tmp/puppet-$$-agent-var --confdir /tmp/puppet-$$-agent --rundir /tmp/puppet-$$-agent \
                --no-daemonize --onetime --server localhost --debug --masterport $MASTER_PORT "$@"
}

function start_puppetmasterd {
        MASTER_PORT=18140
        mkdir -p /tmp/puppet-$$-master/manifests/
        $BIN/../sbin/puppetmasterd --vardir /tmp/puppet-$$-master-var --confdir /tmp/puppet-$$-master --rundir /tmp/puppet-$$-master \
                --no-daemonize --autosign=true --certname=localhost --masterport $MASTER_PORT "$@" &
        MASTER_PID=$!

        for I in `seq 0 10` ; do
                if lsof -i -n -P | grep '\*:'$MASTER_PORT | grep $MASTER_PID > /dev/null ; then
                        break
                else
                        sleep 1
                fi
        done

}

function stop_puppetmasterd {
        kill $MASTER_PID
}

function NOT_APPLICABLE {
        exit 11
}
