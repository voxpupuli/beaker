#!/bin/bash

. ../../local_setup.sh

$BIN/puppet doc -r function | grep 'Function Reference'
