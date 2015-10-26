Beaker maintains yard documentation, which covers the [Beaker DSL](http://www.rubydoc.info/github/puppetlabs/beaker/).



## Assertions ##
To be used for confirming the result of a test is as expected.  Beaker include all Minitest assertions, plus some custom built assertions.

* [Minitest assertions](http://docs.seattlerb.org/minitest/Minitest/Assertions.html)
* [assert_output](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Assertions#assert_output-instance_method)
* [assert_no_match](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Assertions#assert_no_match-instance_method)

## Helpers ##
DSL methods designed to help you interact with installed projects (like facter and puppet), with hosts (like running arbitrary commands on hosts) or interacting with the web (checking is a given URL is alive or not).

### Facter ###
DSL methods for interacting with facter.

* [fact_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/FacterHelpers#fact_on-instance_method)
* [fact](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/FacterHelpers#fact-instance_method)

### Host ###
DSL methods for host manipulation.

* [on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#on-instance_method)
* [shell](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#shell-instance_method)
* [stdout](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#stdout-instance_method)
* [stderr](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#stderr-instance_method)
* [exit_code](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#exit_code-instance_method)
* [scp_from](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#scp_from-instance_method)
* [scp_to](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#scp_to-instance_method)
* [rsync_to](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#rsync_to-instance_method)
* [deploy_package_repo](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#deploy_package_repo-instance_method)
* [create_remote_file](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#create_remote_file-instance_method)
* [run_script_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#run_script_on-instance_method)
* [run_script](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#run_script-instance_method)
* [install_package](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#install_package-instance_method)
* [check_for_package](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#check_for_package-instance_method)
* [upgrade_package](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#upgrade_package-instance_method)
* [add_system32_hosts_entry](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#add_system32_hosts_entry-instance_method)
* [backup_the_file](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#backup_the_file-instance_method)
* [curl_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#curl_on-instance_method)
* [curl_with_retries](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#curl_with_retries-instance_method)
* [retry_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#retry_on-instance_method)
* [run_cron_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#run_cron_on-instance_method)
* [create_tmpdir_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#create_tmpdir_on-instance_method)
* [echo_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#echo_on-instance_method)

### Puppet ###
DSL methods for interacting with puppet.
* [puppet_user](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#puppet_user-instance_method)
* [puppet_group](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#puppet_group-instance_method)
* [with_puppet_running_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#with_puppet_running_on-instance_method)
* [with_puppet_running](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#with_puppet_running-instance_method)
* [restore_puppet_conf_from_backup](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#restore_puppet_conf_from_backup-instance_method)
* [start_puppet_from_source_on!](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#start_puppet_from_source_on!-instance_method)
* [stop_puppet_from_source_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#stop_puppet_from_source_on-instance_method)
* [dump_puppet_log](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#dump_puppet_log-instance_method)
* [lay_down_new_puppet_conf](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#lay_down_new_puppet_conf-instance_method)
* [puppet_conf_for](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#puppet_conf_for-instance_method)
* [bounce_service](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#bounce_service-instance_method)
* [apply_manifest_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#apply_manifest_on-instance_method)
* [apply_manifest](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#apply_manifest-instance_method)
* [run_agent_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#run_agent_on-instance_method)
* [stub_hosts_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#stub_hosts_on-instance_method)
* [with_host_stubbed_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#with_host_stubbed_on-instance_method)
* [stub_hosts](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#stub_hosts-instance_method)
* [stub_forge_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#stub_forge_on-instance_method)
* [with_forge_stubbed_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#with_forge_stubbed_on-instance_method)
* [with_forge_stubbed](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#with_forge_stubbed-instance_method)
* [stub_forge](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#stub_forge-instance_method)
* [sleep_until_puppetdb_started](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#sleep_until_puppetdb_started-instance_method)
* [sleep_until_puppetserver_started](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#sleep_until_puppetserver_started-instance_method)
* [sleep_until_nc_started](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#sleep_until_nc_started-instance_method)
* [stop_agent_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#stop_agent_on-instance_method)
* [stop_agent](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#stop_agent-instance_method)
* [wait_for_host_in_dashboard](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#wait_for_host_in_dashboard-instance_method)
* [sign_certificate_for](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#sign_certificate_for-instance_method)
* [sign_certificate](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#sign_certificate-instance_method)
* [create_tmpdir_for_user](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/PuppetHelpers#create_tmpdir_for_user-instance_method)

### TK ###
Convenience methods for TrapperKeeper configuration.

* [modify_tk_config](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/TkHelpers#modify_tk_config-instance_method)
* [read_tk_config_string](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/TkHelpers#read_tk_config_string-instance_method)

### Web ###
Helpers for web actions.

* [port_open_within?](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/WebHelpers#port_open_within?-instance_method)
* [link_exists?](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/WebHelpers#link_exists?-instance_method)
* [fetch_http_file](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/WebHelpers#fetch_http_file-instance_method)
* [fetch_http_dir](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/WebHelpers#fetch_http_dir-instance_method)

### Test ###
DSL methods for setting information about the current test.

* [current_test_name](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/TestHelpers#current_test_name-instance_method)
* [current_test_filename](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/TestHelpers#current_test_filename-instance_method)
* [current_step_name](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/TestHelpers#current_step_name-instance_method)
* [set_current_test_name](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/TestHelpers#set_current_test_name-instance_method)
* [set_current_test_filename](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/TestHelpers#set_current_test_filename-instance_method)
* [set_current_step_name](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/TestHelpers#set_current_step_name-instance_method)

## Install Utilities ##
DSL methods for installing PuppetLabs projects.

### EZBake ###
EZBake convenience methods.
* [install_from_ezbake](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/EzbakeUtils#install_from_ezbake-instance_method)
* [install_termini_from_ezbake](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/EzbakeUtils#install_termini_from_ezbake-instance_method)
* [ezbake_dev_build](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/EzbakeUtils#ezbake_dev_build-instance_method)
* [ezbake_validate_support](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/EzbakeUtils#ezbake_validate_support-instance_method)
* [install_ezbake_tarball_on_host](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/EzbakeUtils#install_ezbake_tarball_on_host-instance_method)
* [ezbake_tools_available?](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/EzbakeUtils#ezbake_tools_available?-instance_method)
* [ezbake_config](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/EzbakeUtils#ezbake_config-instance_method)
* [ezbake_lein_prefix](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/EzbakeUtils#ezbake_lein_prefix-instance_method)
* [ezbake_stage](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/EzbakeUtils#ezbake_stage-instance_method)
* [ezbake_local_cmd](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/EzbakeUtils#ezbake_local_cmd-instance_method)
* [ezbake_install_name](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/EzbakeUtils#ezbake_install_name-instance_method)
* [ezbake_install_dir](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/EzbakeUtils#ezbake_install_dir-instance_method)
* [ezbake_installsh](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/EzbakeUtils#ezbake_installsh-instance_method)
* [conditionally_clone](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/EzbakeUtils#conditionally_clone-instance_method)

### AIO ###
Agent-only installation utilities.

* [add_platform_aio_defaults](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/AIODefaults#add_platform_aio_defaults-instance_method)
* [add_aio_defaults_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/AIODefaults#add_aio_defaults_on-instance_method)
* [remove_platform_aio_defaults](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/AIODefaults#remove_platform_aio_defaults-instance_method)
* [remove_aio_defaults_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/AIODefaults#remove_aio_defaults_on-instance_method)

### FOSS ###
DSL methods for installing FOSS PuppetLabs projects.

* [add_platform_foss_defaults](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSDefaults#add_platform_foss_defaults-instance_method)
* [add_foss_defaults_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSDefaults#add_foss_defaults_on-instance_method)
* [remove_platform_foss_defaults](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSDefaults#remove_platform_foss_defaults-instance_method)
* [remove_foss_defaults_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSDefaults#remove_foss_defaults_on-instance_method)
* [lookup_in_env](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#lookup_in_env-instance_method)
* [build_git_url](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#build_git_url-instance_method)
* [extract_repo_info_from](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#extract_repo_info_from-instance_method)
* [order_packages](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#order_packages-instance_method)
* [find_git_repo_versions](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#find_git_repo_versions-instance_method)
* [clone_git_repo_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#clone_git_repo_on-instance_method)
* [install_from_git_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_from_git_on-instance_method)
* [install_puppet](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_puppet-instance_method)
* [install_puppet_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_puppet_on-instance_method)
* [install_puppet_agent_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_puppet_agent_on-instance_method)
* [configure_puppet](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#configure_puppet-instance_method)
* [configure_puppet_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#configure_puppet_on-instance_method)
* [install_puppet_from_rpm_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_puppet_from_rpm_on-instance_method)
* [install_puppet_from_deb_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_puppet_from_deb_on-instance_method)
* [install_puppet_from_msi_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_puppet_from_msi_on-instance_method)
* [compute_puppet_msi_name](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#compute_puppet_msi_name-instance_method)
* [install_puppet_agent_from_msi_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_puppet_agent_from_msi_on-instance_method)
* [install_a_puppet_msi_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_a_puppet_msi_on-instance_method)
* [install_puppet_from_freebsd_ports_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_puppet_from_freebsd_ports_on-instance_method)
* [install_puppet_from_dmg_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_puppet_from_dmg_on-instance_method)
* [install_puppet_agent_from_dmg_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_puppet_agent_from_dmg_on-instance_method)
* [install_puppet_from_openbsd_packages_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_puppet_from_openbsd_packages_on-instance_method)
* [install_puppet_from_gem_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_puppet_from_gem_on-instance_method)
* [install_puppetlabs_release_repo_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_puppetlabs_release_repo_on-instance_method)
* [install_puppetlabs_dev_repo](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_puppetlabs_dev_repo-instance_method)
* [install_packages_from_local_dev_repo](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_packages_from_local_dev_repo-instance_method)
* [install_puppet_agent_dev_repo_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_puppet_agent_dev_repo_on-instance_method)
* [install_puppet_agent_pe_promoted_repo_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_puppet_agent_pe_promoted_repo_on-instance_method)
* [install_cert_on_windows](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/FOSSUtils#install_cert_on_windows-instance_method)

### PE ###
DSL methods for installing Puppet Enterprise.

* [add_platform_pe_defaults](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeDefaults#add_platform_pe_defaults-instance_method)
* [add_pe_defaults_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeDefaults#add_pe_defaults_on-instance_method)
* [remove_platform_pe_defaults](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeDefaults#remove_platform_pe_defaults-instance_method)
* [remove_pe_defaults_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeDefaults#remove_pe_defaults_on-instance_method)
* [sorted_hosts](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeUtils#sorted_hosts-instance_method)
* [installer_cmd](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeUtils#installer_cmd-instance_method)
* [fetch_pe_on_mac](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeUtils#fetch_pe_on_mac-instance_method)
* [fetch_pe_on_windows](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeUtils#fetch_pe_on_windows-instance_method)
* [fetch_pe_on_unix](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeUtils#fetch_pe_on_unix-instance_method)
* [fetch_pe](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeUtils#fetch_pe-instance_method)
* [deploy_frictionless_to_master](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeUtils#deploy_frictionless_to_master-instance_method)
* [do_install](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeUtils#do_install-instance_method)
* [create_agent_specified_arrays](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeUtils#create_agent_specified_arrays-instance_method)
* [setup_defaults_and_config_helper_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeUtils#setup_defaults_and_config_helper_on-instance_method)
* [install_pe](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeUtils#install_pe-instance_method)
* [install_pe_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeUtils#install_pe_on-instance_method)
* [upgrade_pe](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeUtils#upgrade_pe-instance_method)
* [upgrade_pe_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeUtils#upgrade_pe_on-instance_method)
* [higgs_installer_cmd](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeUtils#higgs_installer_cmd-instance_method)
* [do_higgs_install](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeUtils#do_higgs_install-instance_method)
* [install_higgs](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeUtils#install_higgs-instance_method)
* [fetch_and_push_pe](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PeUtils#fetch_and_push_pe-instance_method)

### Puppet ###
DSL methods that can be used for both FOSS/PE puppet installations.

* [normalize_type](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PuppetUtils#normalize_type-instance_method)
* [construct_puppet_path](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PuppetUtils#construct_puppet_path-instance_method)
* [add_puppet_paths_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PuppetUtils#add_puppet_paths_on-instance_method)
* [remove_puppet_paths_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PuppetUtils#remove_puppet_paths_on-instance_method)
* [configure_defaults_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PuppetUtils#configure_defaults_on-instance_method)
* [configure_type_defaults_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PuppetUtils#configure_type_defaults_on-instance_method)
* [remove_defaults_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/PuppetUtils#remove_defaults_on-instance_method)

### Windows ###
DSL convenience methods for installing packages on Windows SUTs.

* [get_temp_path](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/WindowsUtils#get_temp_path-instance_method)
* [msi_install_script](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/WindowsUtils#msi_install_script-instance_method)
* [create_install_msi_batch_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/WindowsUtils#create_install_msi_batch_on-instance_method)
* [install_msi_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/WindowsUtils#install_msi_on-instance_method)

### Module ###
DSL methods for installing puppet modules.

* [install_dev_puppet_module_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/ModuleUtils#install_dev_puppet_module_on-instance_method)
* [install_dev_puppet_module](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/ModuleUtils#install_dev_puppet_module-instance_method)
* [install_puppet_module_via_pmt_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/ModuleUtils#install_puppet_module_via_pmt_on-instance_method)
* [install_puppet_module_via_pmt](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/ModuleUtils#install_puppet_module_via_pmt-instance_method)
* [copy_module_to](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/ModuleUtils#copy_module_to-instance_method)
* [parse_for_moduleroot](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/ModuleUtils#parse_for_moduleroot-instance_method)
* [parse_for_modulename](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/ModuleUtils#parse_for_modulename-instance_method)
* [get_module_name](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/ModuleUtils#get_module_name-instance_method)
* [split_author_modulename](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/ModuleUtils#split_author_modulename-instance_method)
* [build_ignore_list](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/InstallUtils/ModuleUtils#build_ignore_list-instance_method)

## Outcomes ##
Methods that indicate how the given test completed (fail, pass, skip or pending).

* [fail_test](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Outcomes#fail_test-instance_method)
* [pass_test](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Outcomes#pass_test-instance_method)
* [pending_test](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Outcomes#pending_test-instance_method)
* [skip_test](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Outcomes#skip_test-instance_method)
* [formatted_message](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Outcomes#formatted_message-instance_method)

## Patterns ##
Shared methods used as building blocks of other DSL methods.

* [block_on](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Patterns#block_on-instance_method)

## Roles ##
DSL methods for accessing hosts of various roles.

* [agents](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#agents-instance_method)
* [master](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#master-instance_method)
* [database](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#database-instance_method)
* [dashboard](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#dashboard-instance_method)
* [default](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#default-instance_method)
* [not_controller](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#not_controller-instance_method)
* [agent_only](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#agent_only-instance_method)
* [aio_version?](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#aio_version?-instance_method)
* [aio_agent?](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#aio_agent?-instance_method)
* [add_role](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#add_role-instance_method)
* [add_role_def](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#add_role_def-instance_method)
* [any_hosts_as?](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#any_hosts_as?-instance_method)
* [hosts_as](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#hosts_as-instance_method)
* [find_host_with_role](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#find_host_with_role-instance_method)
* [find_only_one](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#find_only_one-instance_method)
* [find_at_most_one](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#find_at_most_one-instance_method)

## Structure ##
DSL methods that describe and define how a test is executed.

* [step](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#step-instance_method)
* [test_name](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#test_name-instance_method)
* [teardown](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#teardown-instance_method)
* [expect_failure](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#expect_failure-instance_method)
* [confine](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#confine-instance_method)
* [confine_block](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#confine_block-instance_method)
* [tag](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#tag-instance_method)
* [select_hosts](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#select_hosts-instance_method)
* [inspect_host](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Structure#inspect_host-instance_method)

## Wrappers ##
Wrappers around commonly used commands.

* [facter](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Wrappers#facter-instance_method)
* [cfacter](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Wrappers#cfacter-instance_method)
* [hiera](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Wrappers#hiera-instance_method)
* [puppet](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Wrappers#puppet-instance_method)
* [powershell](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Wrappers#powershell-instance_method)
