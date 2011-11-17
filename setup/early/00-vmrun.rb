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

  # Set snapshot name for special cases
  snapshot=options[:snapshot] if options[:snapshot] 

  hosts.each do |host|
    step "Reverting VM: #{host} to #{snapshot} on VM server #{vmserver}"
    system("lib/virsh_exec.exp #{vmserver} snapshot-revert #{host} #{snapshot}")
  end

else
  Log.notify "Skipping revert VM step"  
  skip_test "Skipping revert VM step"
end
