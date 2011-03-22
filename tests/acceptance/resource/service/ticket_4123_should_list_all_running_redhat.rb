test_name "#4123: should list all running services on Redhat/CentOS"

step "Validate sservices running agreement ralsh vs. OS service count"

# This will remotely exec:
# ticket_4123_should_list_all_running_redhat.sh
# and parse the results

rexec_dir="/opt/puppet-git-repos/puppet-acceptance/remote_exec"

hosts.each do |host|
  if host['platform'].include? 'redhat' || 'centos'
    on host,"#{rexec_dir}/ticket_4123_should_list_all_running_redhat.sh #{host['platform']}"
  end
end
