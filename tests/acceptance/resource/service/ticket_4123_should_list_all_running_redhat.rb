test_name "#4123: should list all running services on Redhat/CentOS"
step "Validate sservices running agreement ralsh vs. OS service count"
# This will remotely exec:
# ticket_4123_should_list_all_running_redhat.sh

hosts.each do |host|
  if host['platform'].include? 'centos'
    run_script_on(host,'tests/acceptance/resource/service/ticket_4123_should_list_all_running_redhat.sh')
  end
end
