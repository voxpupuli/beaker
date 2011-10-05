# Puppet Enterprise install via NFS RO mount

# Determine NFS server from config
nfs_server = config['nfs_server']
version  = config['pe_ver']

# Build hash hostname=>tarball
disthash = Hash.new
hosts.each do |host|
  platform = host['platform']
  dist_tar = "puppet-enterprise-#{version}-#{platform}.tar.gz"
  disthash[host] = dist_tar
end

# Set up a RW mount on the Master for RW operations
step "Pre Test Setup -- NFS mount RW dir"
on master,"if [ ! -d /mnt/rw ] ; then mkdir /mnt/rw; fi; mount -t nfs #{nfs_server}:/exports /mnt/rw"

# Only SCP the needed tarballs ONCE
disthash.map { |k,v| v }.uniq.each do |file| 
  step "Pre Test Setup -- SCP tarballs to NFS RW mount"
  scp_to master, "/opt/enterprise/dists/#{file}", "/mnt/rw/pe"
  step "Pre Test Setup -- extract tarballs on NFS RW mount"
  on master, "tar xzf /mnt/rw/pe/#{file} -C /mnt/rw/pe"
end

step "Pre Test Setup -- SCP answer files to NFS RW mount"
scp_to master,"tarballs/answers.*", "/tmp"
step "Pre Test Setup -- extract answer.tar on NFS RW mount"

# Mount NFS RO mount point on all hosts
hosts.each do |host|
  step "Pre Test Setup -- NFS mount distribution dir"
  on host,"if [ ! -d /mnt/ro ] ; then mkdir /mnt/ro ; fi; mount -t nfs --read-only #{nfs_server}:/exports /mnt/ro"
end
