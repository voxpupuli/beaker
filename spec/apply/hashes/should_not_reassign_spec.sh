set -e

. local_setup.sh

# hash reassignment should fail
! puppet apply <<PP | grep "Assigning to the hash 'my_hash' with an existing key 'one'"
\$my_hash = {'one' => '1', 'two' => '2' }
\$my_hash['one']='1.5'  
PP
