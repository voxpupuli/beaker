#!/bin/bash

source spec/setup.sh

puppet cert --trace --generate test01.domain.tld --ssldir=/tmp/puppet-ssl-$$ --debug --verbose

ls /tmp/puppet-ssl-$$/certs/*
