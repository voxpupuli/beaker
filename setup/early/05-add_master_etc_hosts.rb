test_name "Add Master entry to /etc/hosts"

step "Get ip address of Master #{master}"
on(master,"ip a|awk '/g/{print$2}' | cut -d/ -f1")
ip=stdout.chomp
step "Update /etc/host on #{master}"
on(master,"echo \"#{ip} #{master}\" >> /etc/hosts")
