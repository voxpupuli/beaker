#!/bin/bash

function start_puppet_master {
        MASTER_PORT=18140
        $BIN/puppet master --vardir /tmp/puppet-$$ --confdir /tmp/puppet-$$ --rundir /tmp/puppet-$$ \
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
