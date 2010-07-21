#!/bin/bash

## JJM Variables for exit codes
EXIT_NOT_APPLICABLE=11
EXIT_OK=0
EXIT_FAILURE=1

# JJM Raise an error when unbound variables are used.
set -u

# JJM Start the puppet agent against port 18140
start_puppet_agent() {
  local master_port=${MASTER_PORT:=18140}
  $BIN/puppet agent --vardir /tmp/puppet-$$-agent-var \
    --confdir /tmp/puppet-$$-agent \
    --rundir /tmp/puppet-$$-agent \
    --test --debug \
    --server localhost \
    --masterport ${master_port} "$@"
  return $?
}

start_puppet_master() {
  local master_port=${MASTER_PORT:=18140}
  mkdir -p /tmp/puppet-$$-master/manifests/
  $BIN/puppet master --vardir \
    /tmp/puppet-$$-master-var \
    --confdir /tmp/puppet-$$-master \
    --rundir /tmp/puppet-$$-master \
    --no-daemonize --autosign=true \
    --certname=localhost \
    --masterport ${master_port} $@ &
  local master_pid=$!
  # JJM Set the master PID available outside
  MASTER_PID=${master_pid}

  # Watch for the puppet master port to come online
  for x in $(seq 0 10); do
    rval=2
    if (lsof -i -n -P|grep '\*:'${master_port}|grep -q ${master_pid})
    then
      rval=${EXIT_OK}
      break
    else
      sleep 1
    fi
  done
  return ${rval}
}

# JJM Stop the puppet master.  Expects ${MASTER_PID}
stop_puppet_master() {
  kill -TERM ${MASTER_PID}
}

start_puppetd() {
  local master_port=${MASTER_PORT:=18140}
  $BIN/../sbin/puppetd --vardir /tmp/puppet-$$-agent-var \
    --confdir /tmp/puppet-$$-agent \
    --rundir /tmp/puppet-$$-agent \
    --test --debug \
    --server localhost --masterport ${master_port} "$@"
}

start_puppetmasterd() {
  local master_port=${MASTER_PORT:=18140}
  mkdir -p /tmp/puppet-$$-master/manifests
  $BIN/../sbin/puppetmasterd \
    --vardir /tmp/puppet-$$-master-var \
    --confdir /tmp/puppet-$$-master \
    --rundir /tmp/puppet-$$-master \
    --no-daemonize --autosign=true \
    --certname=localhost --masterport ${master_port} "$@" &
  MASTER_PID=$!

  # JJM Wait for puppet master to start and open up the TCP port.
  for i in $(seq 0 10); do
    if lsof -i -n -P | grep '\*:'${master_port} | grep -q $MASTER_PID
    then
      break
    else
      sleep 1
    fi
  done
}

stop_puppetmasterd() {
  kill -TERM $MASTER_PID
}

NOT_APPLICABLE() {
  exit $EXIT_NOT_APPLICABLE
}
#
