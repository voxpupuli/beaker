#!/bin/bash

. `dirname $0`/setup.sh

$BIN/puppet cert --trace --generate test01.domain.tld --ssldir=/tmp/puppet-ssl-$$ --debug --verbose

ls /tmp/puppet-ssl-$$/certs/*
