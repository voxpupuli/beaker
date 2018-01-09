#!/usr/bin/env bash

top_level=$(git rev-parse --show-toplevel)
acceptance_test_base="$top_level/acceptance/tests/base"

find $acceptance_test_base -type f -name '*.rb' |
grep -v host_test.rb |
awk 'BEGIN {
  comma_index = 1
} {
  if (comma_index == 1) {
    comma_string = $0
  } else {
    comma_string = comma_string "," $0
  }
  comma_index = comma_index + 1
} END {
  print comma_string
}'
