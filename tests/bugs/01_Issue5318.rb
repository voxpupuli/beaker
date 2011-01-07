
test_name "Issue5318"

agent = agents.first

step 0,"Query Puppet master for filetimeout value"
    on master,"puppet --configprint all | grep filetimeout"
    if filetimeout = stdout[/filetimeout \= \'(\d+)\'/,1]
      puts "Master reported file timeout value of: #{filetimeout}"
    else 
      fail_test "Master file timeout value not reported!" 
    end

step 1,	"Add 'origina' notify to site.pp file on Master"
    on master,'echo notify{\"issue5318 original\":} >> /etc/puppetlabs/puppet/manifests/site.pp'

step 2, "Invoke puppet agent to get the config version"
    on agent,"puppet agent --no-daemonize --verbose --onetime --test"
    config_ver_org = stdout[/Applying configuration version \'(\d+)\'/,1]

step 3, "Add 'modified' notify to site.pp on Master (and sleep for for file timeout+2 seconds)"
    on master,'echo notify{\"issue5318 modified\":} >> /etc/puppetlabs/puppet/manifests/site.pp'
    sleep (filetimeout || 0)+2

step 4, "Invoke puppet agent again to get the new config version"
    on agent, "puppet agent --no-daemonize --verbose --onetime --test"
    config_ver_mod = stdout[/Applying configuration version \'(\d+)\'/,1]

step 5, "Compare config versions from steps 2 & 4"
    if config_ver_org == config_ver_mod then 
      fail_test "Agent did not receive updated config: ORG #{config_ver_org} MOD #{config_ver_mod}"
    else
      pass_test "Agent received updated config: ORG #{config_ver_org} MOD #{config_ver_mod}"
    end
