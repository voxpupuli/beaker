#!/bin/sh

# takes two or three positional parameters: DIRECTORY and files||dir
# DIRECTORY: is the file store where to look for Puppet served files/dirs
# files||dir Look for served files or served dirs
# $3 is the number of dirs to look for the given directory

fail_flag=0
absent_files=""
absent_dir=""

# Target dir to check files/create files
cd $1

# verify small, med, large files
# args: directory_to_look_for_file files_flag
if [ "${2}" == "files" ]; then
  #file_list="file_0 file_1 file_100 file_100000"
  file_list="file_0 file_1 file_100"
  for file in $file_list; do
    if [ ! -f "$file" ]; then
     absent_files=${file}" "${absent_files}
     let fail_flag++
    fi
  done
  echo "Sized files missing (0K, 1K, 100K, 100000K): ${absent_files}"
fi

# verify large file count dir
# args: directory dir_flag dir_count
if [ "${2}" == "dir" ]; then

  for ((n=1; n <= ${3}; n++)); do
    if  [ ! -f many_files/"file.${n}" ]; then
     absent_dir=file.${n}" "${absent_dir}
     let fail_flag++
    fi
  done
  echo "High file count files missing: ${absent_dir}"
fi

exit $fail_flag
