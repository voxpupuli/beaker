file_count=10  # Default files to create

step "Initiate File Transfer on Agents"
run_agent_on agents

# verify sized (0, 10, 100K)) files have been transfered to agents
step "Verify File Existence on Agents"
on agents,'/ptest/bin/fileserve.sh /root files'
