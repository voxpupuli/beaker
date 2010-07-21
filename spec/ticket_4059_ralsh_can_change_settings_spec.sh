#!/bin/bash

source spec/setup.sh

puppet resource host example.com ensure=present ip=127.0.0.1 target=/tmp/hosts-$$ --trace

grep 'example\.com' /tmp/hosts-$$
