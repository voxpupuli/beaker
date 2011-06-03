file_count = config['filecount'] || 10 
test_name "Verifying #{file_count} files" do

  step "Initiate Directory Transfer on Agents" do
    run_agent_on agents
  end

  step "Verify Directory Existence on Agents" do
    on agents,"/ptest/bin/fileserve.sh /root dir #{file_count}"
  end
end
