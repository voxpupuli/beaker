version  = config['pe_ver']

test_name "Fetch PE #{version}"
confine :except, :platform => 'windows'

if options[:pe_version]
  distpath = "#{config['pe_dir']}/pe#{version}"
else
  distpath = "#{config['pe_dir']}"
end

def is_http(path)
  path =~ /^https?:\/\/.+/
end

if version =~ /^1.*/ # Older version of PE, 1.x series
  hosts.each do |host|
    platform = host['platform']
    # FIXME hack-o-rama: this is likely to be fragile and very PE 1.0, 1.1 specifc:
    # Tarballs have changed name rhel- is now el- and affects package naming
    # change el- to rhel- to match the old tarball naming/paths.
    # It gets worse, of course, as Centos differs from RHEL as well
    if version =~ /^1.1/ 
      if platform =~ /el-(.*)/ and host.name.include? 'cent'
         platform = "centos-#{$1}" 
      elsif platform =~ /el-(.*)/ and host.name.include? 'rhel'
        platform = "rhel-#{$1}" 
      end
    end
    host['dist'] = "puppet-enterprise-#{version}-#{platform}"
  
    unless File.file? "#{distpath}/#{host['dist']}.tar.gz"
      logger.error "PE #{host['dist']}.tar not found, help!"
      logger.error ""
      logger.error "Make sure your configuration file uses the PE version string:"
      logger.error "  eg: rhel-5-x86_64  centos-5-x86_64"
      fail_test "Sorry, PE #{host['dist']}.tar file not found."
    end
  
    step "Pre Test Setup -- SCP install package to hosts"
    scp_to host, "#{distpath}/#{host['dist']}.tar.gz", "/tmp"
    step "Pre Test Setup -- Untar install package on hosts"
    on host,"cd /tmp && gunzip #{host['dist']}.tar.gz && tar xf #{host['dist']}.tar"
  end
else
  hosts.each do |host|
    platform = host['platform']
    puts "Version is #{version}"
    host['dist'] = "puppet-enterprise-#{version}-#{platform}"

    step "Pre Test Setup -- copy install package to hosts"
    if is_http "#{distpath}"
      on host, "curl #{distpath}/#{host['dist']}.tar.gz -o /tmp/#{host['dist']}.tar.gz"
    else
      unless File.file? "#{distpath}/#{host['dist']}.tar.gz"
        logger.error "PE #{host['dist']}.tar.gz not found, help!"
        logger.error ""
        logger.error "Make sure your configuration file uses the PE version string:"
        logger.error "  eg: rhel-5-x86_64  centos-5-x86_64"
        fail_test "Sorry, PE #{host['dist']}.tar.gz file not found."
      end
      scp_to host, "#{distpath}/#{host['dist']}.tar.gz", "/tmp"
    end
    step "Pre Test Setup -- Untar install package on hosts"
    on host,"cd /tmp && gunzip #{host['dist']}.tar.gz && tar xf #{host['dist']}.tar"
  end
end
