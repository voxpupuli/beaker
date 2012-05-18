test_name "Config Packing Repository"
# Currently, this is specific to Linux
confine :except, :platform => 'windows'

aptcfg = %q{ Acquire::http::Proxy "http://modi.puppetlabs.lan:3128/"; }

el6_64 = %q{ [puppetlabs_local_os]
name=RHEL-$releasever - Base
baseurl=http://yo.puppetlabs.lan/rhel6server-x86_64/RPMS.os
gpgcheck=0 

#released updates
[puppetlabs_local_updates]
name=RHEL-$releasever - Updates
baseurl=http://yo.puppetlabs.lan/rhel6server-x86_64/RPMS.updates
gpgcheck=0 }

el6_32 = %q{ 
[puppetlabs_local_os]
name=RHEL-$releasever - Base
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=os
baseurl=http://yo.puppetlabs.lan/rhel6server-i386/RPMS.os
gpgcheck=0

#released updates
[puppetlabs_local_updates]
name=RHEL-$releasever - Updates
baseurl=http://yo.puppetlabs.lan/rhel6server-i386/RPMS.updates
gpgcheck=0
}

unless options[:pkg_repo]
  skip_test "Skipping Config Packing Repository"
else
  hosts.each do |host|
    case
    when host['platform'] =~ /ubuntu/
      on(host, "mv /etc/apt/apt.conf /etc/apt/apt.conf.bk") 
      create_remote_file(host, '/etc/apt/apt.conf', aptcfg) 
    when host['platform'] =~ /el-6-x86_64/
      on(host, "mv /etc/yum.repos.d/puppetlabs.lan.repo /etc/yum.repos.d/puppetlabs.lan.repo.bk") 
      create_remote_file(host, '/etc/yum.repos.d/puppetlabs.lan.repo', el6_64) 
    when host['platform'] =~ /el-6-i386/
      on(host, "mv /etc/yum.repos.d/puppetlabs.lan.repo /etc/yum.repos.d/puppetlabs.lan.repo.bk") 
      create_remote_file(host, '/etc/yum.repos.d/puppetlabs.lan.repo', el6_32) 
    else
      Log.notify "#{host}: packing configuration not modified"  
    end
  end
end
