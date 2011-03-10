module VmManage
  def vmrun(config)
    vminfo_h = Hash.new
    PTY.spawn("/opt/libvirt/bin/virsh -c esx://root@soko/?no_verify=1") do |r_f,w_f,pid|
      w_f.sync = true
      $expect_verbose = false

      # Login
      r_f.expect(/^Enter root's password for soko: /) do
        w_f.print "Puppetmaster!\n"
      end

      # Send list command
      r_f.expect("virsh # ") do
        w_f.print "list\n"
      end

      # Parse output for VM instances
      r_f.expect("virsh # ") do |output|
        for x in output[0].split("\n")
          hosts.each do |host|  # only add lines that match a hostname
            if x.index(host)
              # VM list is returned as:
              # 16 hostname vm_state
              if x =~ /\s(\d+\s\S+)\s/ then
                k,v = x.split(" ")
                vminfo_h[v]=k
              end
            end
          end
        end
      end
      vminfo_h.each { |key, val|
        puts "KEY: #{key}  VAL: #{val}"
      }

      # Revert to snapshot
      #vminfo_h.each { |key, val|
      #  puts "reverting #{key}"
      #  r_f.expect("virsh # ") do
      #    w_f.print "snapshot-revert #{val} git\n"
      #  end
      #}

      begin
        w_f.print "quit\n"
      rescue
      end
    end  # spawn

    puts "Found VMs : \n"
    vminfo_h.each { |key, val|
      puts "KEY: #{key}  VAL: #{val}"
    }
  end
end
