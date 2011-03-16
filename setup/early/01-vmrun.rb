if options[:vmrun] = options[:type]
  require 'timeout'

  def virsh(*args)
    secret = '/etc/plharness/secret'
    uri    = 'esx://root@soko/?no_verify=1'
    cmd    = args.join(' ')
    output = `virsh -c #{uri} #{cmd} < #{secret}`

    # Meh.  This is ugly but useful. --daniel 2011-03-16
    output.sub!(/Enter root's password for soko: /, '')

    puts "virsh> #{cmd}"
    output.each { |line| puts "virsh< #{line}" }

    return output
  end

  step "Reverting and starting VMs"

  vminfo_h = Hash.new

  # get list of VMs
  hlist = virsh 'list'

  # interate through the VMs...
  hlist.each do |line|
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
    step "Reverting VM: #{key} on ESX domain #{val}"
    virsh 'snapshot-revert', val, 'git'
  end
end
