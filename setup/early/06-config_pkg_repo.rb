test_name "Config Packing Repository"
# Currently, this is specific to Linux
confine :except, :platform => 'windows'

unless options[:pkg_repo]
  skip_test "Skipping Config Packing Repository"
else
  aptcfg = %q{ Acquire::http::Proxy "http://modi.puppetlabs.lan:3128/"; }
  hosts.each do |host|
    case
    when host['platform'] =~ /debian|ubuntu/
      on(host, "mv /etc/apt/apt.conf /etc/apt/apt.conf.org") 
      create_remote_file(host, '/etc/apt/apt.conf', aptcfg) 
    else
      Log.notify "#{host}: packing configuration not modified"  
    end
  end
end
