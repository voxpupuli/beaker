#!/bin/bash

source spec/setup.sh

execute_manifest <<'PP'
notify { 'a\nb': }
PP

