test_name "Add Master entry to /etc/hosts"

step "Get ip address of Master #{master}"
if master['platform'].include? 'solaris'
  on(master,"ifconfig -a inet| awk '/broadcast/ {print $2}' | cut -d/ -f1 | head -1")
else
  on(master,"ip a|awk '/g/{print$2}' | cut -d/ -f1 | head -1")
end
ip=stdout.chomp

path = "/etc/hosts"
if master['platform'].include? 'solaris'
  path = "/etc/inet/hosts"
end

step "Update %s on #{master}" % path
# Preserve the mode the easy way...
on master, "cp %s %s.old" % [path, path]
on master, "cp %s %s.new" % [path, path]
on master, "grep -v '#{ip} #{master}' %s > %s.new" % [path, path]
on master, "echo \"#{ip} #{master}\" >> %s.new" % path
on master, "mv %s.new %s" % [path, path]
