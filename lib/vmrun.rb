module VmManage
  def vmrun(config)
    vminfo_h = Hash.new

    # get list of VMs
    hlist=`lib/virsh_exec.exp list`

    # interate through the VMs...
    hlist.split("\n").each do |line|
      puts line
      hosts.each do |host|  # only add VMs that match a hostname
        if line.index(host)
          if line =~ /\s(\d+\s\S+)\s/ then
            k,v = line.split(" ")
              vminfo_h[v]=k
          end
        end
      end
    end

    # Revert the VMs
    vminfo_h.each do |key, val|
      puts "Reverting VM: #{key} on ESX domain #{val}"
      system("lib/virsh_exec.exp snapshot-revert #{val} git") 
    end

  end
end   
