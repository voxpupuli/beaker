file_count = config['filecount'] || 10  # Default files to create

step "Prep For File and Dir servering tests"
step "Setup: Creating #{file_count} files"
on master,"/ptest/bin/make_files.sh /etc/puppetlabs/puppet/modules/puppet_system_test/files #{file_count}"

# Write new class to init.pp
prep_initpp(master, "file")

step "Initiate File Transfer on Agents"
run_agent_on agents

# verify sized (0, 10, 100K)) files have been transfered to agents
step "Verify File Existence on Agents"
on agents,'/ptest/bin/fileserve.sh /root files'
