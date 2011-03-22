test_name "#4124: should list all disabled services on Redhat/CentOS"

step "Validate disabled services agreement ralsh vs. OS service count"

# This will remotely exec:
# ticket_4124_should_list_all_disabled.sh
# and parse the results

rexec_dir="/opt/puppet-git-repos/puppet-acceptance/remote_exec"

hosts.each do |host|
  if host['platform'].include? 'redhat' || 'centos'
    on host,"#{rexec_dir}/ticket_4124_should_list_all_disabled.sh #{host['platform']}"
  end
end
