file_count = config['filecount'] || 10 
puts "Verifying #{file_count} files"

step "Initiate Directory Transfer on Agents"
run_agent_on agents

step "Verify Directory Existence on Agents"
on agents,"/ptest/bin/fileserve.sh /root dir #{file_count}"
