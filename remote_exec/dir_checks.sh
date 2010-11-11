#!/bin/bash

# -f  file is a regular file (not a directory or device file)
# -s  file is not zero size
# -d  file is a directory
#
# -r  file has read permission (for the user running the test)
# -w  file has write permission (for the user running the test)
# -x  file has execute permission (for the user running the test)

fail_flag=0

dir_list="dir1 dir2 dir3"
for dir in $dir_list; do
  if [ ! -d "$dir" ]; then
   absent=${dir}" "${absent}
   let fail_flag++
  fi
done
echo "Directores missing: ${absent}"
