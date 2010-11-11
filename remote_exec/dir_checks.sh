#!/bin/bash

# -f  file is a regular file (not a directory or device file)
# -s  file is not zero size
# -d  file is a directory
#
# -r  file has read permission (for the user running the test)
# -w  file has write permission (for the user running the test)
# -x  file has execute permission (for the user running the test)

dir_list="dir1 dir2 dir3"
for dir in $dir_list; do
  if [ ! -f "$dir" ] ||  [ ! -s "$dir" ]; then
    echo $dir
  fi
done

