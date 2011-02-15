test_name "Issue5318" do

  agent = agents.first

  step "Query Puppet master for filetimeout value" do
    on master,"puppet --configprint all | grep filetimeout"
    if filetimeout = stdout[/filetimeout \= \'(\d+)\'/,1]
      puts "Master reported file timeout value of: #{filetimeout}"
    else 
      fail_test "Master file timeout value not reported!" 
    end
  end

  step "Add 'original' notify to site.pp file on Master" do
    on master,'echo notify{\"issue5318 original\":} >> /etc/puppetlabs/puppet/manifests/site.pp'
  end

  step "Invoke puppet agent to get the config version" do
    on agent,"puppet agent --no-daemonize --verbose --onetime --test"
    config_ver_org = stdout[/Applying configuration version \'(\d+)\'/,1]
  end

  step "Add 'modified' notify to site.pp on Master (and sleep for for file timeout+2 seconds)" do
    on master,'echo notify{\"issue5318 modified\":} >> /etc/puppetlabs/puppet/manifests/site.pp'
    sleep (filetimeout || 0)+2
  end

  step "Invoke puppet agent again to get the new config version" do
    on agent, "puppet agent --no-daemonize --verbose --onetime --test"
    config_ver_mod = stdout[/Applying configuration version \'(\d+)\'/,1]
  end

  step "Compare config versions from steps 2 & 4" do
    if config_ver_org == config_ver_mod then 
      fail_test "Agent did not receive updated config: ORG #{config_ver_org} MOD #{config_ver_mod}"
    else
      pass_test "Agent received updated config: ORG #{config_ver_org} MOD #{config_ver_mod}"
    end
  end
end
