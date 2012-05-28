test_name "Config Packing Repository"
# Currently, this is specific to Linux
confine :except, :platform => 'windows'

aptcfg = %q{ Acquire::http::Proxy "http://modi.puppetlabs.lan:3128/"; }

unless options[:pkg_repo]
  skip_test "Skipping Config Packing Repository"
else
  hosts.each do |host|
    case
    when host['platform'] =~ /ubuntu/
      on(host, "mv /etc/apt/apt.conf /etc/apt/apt.conf.bk") 
      create_remote_file(host, '/etc/apt/apt.conf', aptcfg) 
      on(host, "apt-get -y -f -m update") 
    else
      Log.notify "#{host}: packing configuration not modified"  
    end
  end
end
