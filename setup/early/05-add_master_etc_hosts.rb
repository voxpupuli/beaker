test_name "Add Master entry to /etc/hosts"

step "Get ip address of Master #{master}"
on(master,"ip a|awk '/g/{print$2}' | cut -d/ -f1 | head -1")
ip=stdout.chomp

step "Update /etc/host on #{master}"
# Preserve the mode the easy way...
on master, "cp /etc/hosts /etc/hosts.old"
on master, "cp /etc/hosts /etc/hosts.new"
on master, "grep -v '#{ip} #{master}' /etc/hosts > /etc/hosts.new"
on master, "echo \"#{ip} #{master}\" >> /etc/hosts.new"
on master, "mv /etc/hosts.new /etc/hosts"
