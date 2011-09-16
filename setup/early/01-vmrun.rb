test_name "Revert VMs"

if options[:vmrun]
  vmserver = options[:vmrun]
  # VM snapshots are named to match the type of Puppet install;
  # the VMs have specific configs to test each install type
  # 'git' = install from git
  # 'pe' = install Puppet Enterpise
  
  # git and gem intalls use the same snapshot 'git'
  # pe installs all use the snapshot 'pe'
  if options[:type] =~ /git/ || options[:type] =~ /gem/ then
    snapshot = 'git'
  elsif options[:type] =~ /pe/ then
    snapshot = 'pe'
  else
    fail_test "Unable to determine snaphot to revert!"
  end 

  # Set snapshot name for specia cases
  snapshot=options[:snapshot] if options[:snapshot] 

  step "Reverting to snapshot #{snapshot} on VM Server #{vmserver}"
  vminfo_h = Hash.new
  # get list of VMs
  hlist=`lib/virsh_exec.exp #{vmserver} list`

  # interate through the VMs...
  hlist.split("\n").each do |line|
    Log.debug("VM: considering '#{line}'")
    hosts.each do |host|  # only add VMs that match a hostname
      if line.index(host)
        if line =~ /(\d+\s\S+)\s/ then
          k,v = line.split(" ")
          vminfo_h[v]=k
        end
      end
    end
  end

  # Revert the VMs
  vminfo_h.each do |key, val|
    step "Reverting VM: #{key} with Domain: #{val} on VM server #{vmserver}"
    system("lib/virsh_exec.exp #{vmserver} snapshot-revert #{val} #{snapshot}")
  end
else
  Log.notify "Skipping revert VM step"  
  skip_test "Skipping revert VM step"
end
