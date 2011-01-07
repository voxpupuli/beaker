#!/bin/sh

# takes two positional parameters: DIRECTORY and num FILES to create
# DIRECTORY: is the file store where to look for Puppet served files/dirs
# FILES: number of files to create for many files check

fail_flag=0
wrkdir=`pwd`

# Target dir to check fir files
cd $1

# create file sizes: 0, 1K, 100K, 100000K 
#file_list="0 1 100 100000"
file_list="0 1 100"
for file in $file_list; do
  /bin/dd bs=1024 count=${file} if=/dev/urandom of=file_${file}
  let fail_flag+=$?
done

# Create files for the many file/dir test
rm -rf many_files
mkdir many_files
cd many_files
let fail_flag+=$?

for ((n=1; n <= ${2}; n++)); do
  echo file ${n} > file.${n}
  let fail_flag+=$?
done

exit $fail_flag
