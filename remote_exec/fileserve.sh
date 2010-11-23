#!/bin/bash

# -f  file is a regular file (not a directory or device file)
# -s  file is not zero size
# -d  file is a directory
#
# -r  file has read permission (for the user running the test)
# -w  file has write permission (for the user running the test)
# -x  file has execute permission (for the user running the test)
fail_flag=0
absent=""
absent_many=""

cd $1

# verify small, med, large files
file_list="zero_file small_file med_file big_file"
for file in $file_list; do
  if [ ! -f "$file" ]; then
   absent=${file}" "${absent}
   let fail_flag++
  fi
done
echo "Sized files missing (sm, med, lg): ${absent}"

# verify large file count dir

for n in {1..5003}; do
  if  [ ! -f many_files/"${n}.file" ]; then
   absent_many=${n}.file" "${absent_many}
   let fail_flag++
  fi
done
echo "High file count files missing: ${absent_many}"

exit $fail_flag
