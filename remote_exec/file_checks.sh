#!/bin/bash

# -f  file is a regular file (not a directory or device file)
# -s  file is not zero size
# -d  file is a directory
#
# -r  file has read permission (for the user running the test)
# -w  file has write permission (for the user running the test)
# -x  file has execute permission (for the user running the test)
fail_flag=0

file_list="file0 file1 file2 file3 foofile"
for file in $file_list; do
  if [ ! -f "$file" ]; then
   absent=${file}" "${absent}
   let fail_flag++
  fi
done
echo "Files missing: ${absent}"

for file in $file_list; do
  if  [ ! -s "$file" ]; then
   empty=${file}" "${empty}
   let fail_flag++
  fi
done
echo "Files empty: ${empty}"
exit $fail_flag
