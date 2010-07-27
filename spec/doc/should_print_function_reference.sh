#!/bin/bash

source lib/setup.sh

puppet doc -r function | grep 'Function Reference'
