#!/bin/sh

# takes two or three positional parameters: DIRECTORY and files||dir
# DIRECTORY: is the file store where to look for Puppet served files/dirs
# files||dir Look for served files or served dirs
# $3 is the number of dirs to look for the given directory

fail_flag=0
absent_files=""
absent_dir=""

# Target dir to check fir files
cd $1

# verify small, med, large files
# args: directory_to_look_for_file files_flag
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
# args: directory dir_flag dir_count
if [ "${2}" == "dir" ]; then

  for ((n=1; n <= ${3}; n++)); do
    if  [ ! -f many_files/"${n}.file" ]; then
     absent_dir=${n}.file" "${absent_dir}
     let fail_flag++
    fi
  done
  echo "High file count files missing: ${absent_dir}"
fi

exit $fail_flag
