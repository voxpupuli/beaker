. local_setup.sh

echo "notice 'Hello World'" | $BIN/puppet apply | grep 'notice:.*Hello World'
