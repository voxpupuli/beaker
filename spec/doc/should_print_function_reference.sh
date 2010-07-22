#!/bin/bash

. ../../local_setup.sh

puppet doc -r function | grep 'Function Reference'
