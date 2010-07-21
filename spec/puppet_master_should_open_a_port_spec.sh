. local_setup.sh

PORT=18140

puppet master --masterport $PORT --vardir /tmp/puppet-$$ --confdir /tmp/puppet-$$ --rundir /tmp/puppet-$$ --no-daemonize &
PUPPET_PID=$!

for I in `seq 0 10` ; do
        if lsof -i -n -P | grep '\*:'$PORT | grep $PUPPET_PID ; then
                let status=0
                break
        else
                let status=1
                sleep 1
        fi
done

kill $PUPPET_PID

exit $status
