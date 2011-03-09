module VmManage
  def vmrun(config)

  vms = []
  PTY.spawn("/opt/libvirt/bin/virsh -c esx://root@soko/?no_verify=1") do |r_f,w_f,pid|
    w_f.sync = true
    $expect_verbose = false

    # Login
    r_f.expect(/^Enter root's password for soko: /) do
      w_f.print "Puppetmaster!\n"
    end

    # Send command
    r_f.expect("virsh # ") do
      w_f.print "list\n"
    end

    # Parse output for VM instances
    r_f.expect("virsh # ") do |output|
      for x in output[0].split("\n")
        if x =~ /\s(\w.*centos.*)\s.*\w/ then
          vms.push $1
        end
      end
    end
    begin
      w_f.print "quit\n"
    rescue
    end
  end

  vminfo_h = Hash.new
  puts "Found VMs : \n"
  vms.each do |line|
    k,v = line.split(" ")
    vminfo_h[v]=k
  end

  vminfo_h.each { |key, val|
    puts "KEY: #{key}  VAL: #{val}"
  }

hosts.each do |host|
  puts host
end

  end
end
