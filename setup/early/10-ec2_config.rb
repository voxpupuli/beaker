test_name "Config steps for EC2 hosts"

if options[:vmrun] == 'blimpy' && options[:type] !~ /pe/
  step "Install git and ruby"
  hosts.each do |host|
  
    if host['platform'].include?('el-5')
      on host, "wget http://download3.fedora.redhat.com/pub/epel/5Server/i386/epel-release-5-4.noarch.rpm && rpm -ihv epel-release-5-4.noarch.rpm"
    end
  
    if host['platform'].include?('el-')
        on host, "yum -y install git ruby"
    elsif host['platform'].include?('ubuntu') or host['platform'].include?('debian')
        on host, "apt-get -y install git-core ruby"
    else
      Log.debug "Warn #{host} is not a supported platform, no packages will be installed."
      next
    end
  end
else
  skip_test "Not syncing root authorized_keys from github"
end
