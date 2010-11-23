#!/bin/bash

# -f  file is a regular file (not a directory or device file)
# -s  file is not zero size
# -d  file is a directory
#
# -r  file has read permission (for the user running the test)
# -w  file has write permission (for the user running the test)
# -x  file has execute permission (for the user running the test)

# takes two positional parameters: DIRECTORY and files||dir
# DIRECTORY: is the file store where to look for Puppet served files/dirs
# files||dir Look for served files or served dirs

fail_flag=0
absent_files=""
absent_dir=""

cd $1

# verify small, med, large files
if [ "${2}" == "files" ]; then
  file_list="zd_file sm_file md_file lg_file"
  for file in $file_list; do
    if [ ! -f "$file" ]; then
     absent_files=${file}" "${absent_files}
     let fail_flag++
    fi
  done
  echo "Sized files missing (zd, sm, md, lg): ${absent_files}"
fi

# verify large file count dir
if [ "${2}" == "dir" ]; then
  for n in {1..5000}; do
    if  [ ! -f many_files/"${n}.file" ]; then
     absent_dir=${n}.file" "${absent_dir}
     let fail_flag++
    fi
  done
  echo "High file count files missing: ${absent_dir}"
fi

exit $fail_flag
