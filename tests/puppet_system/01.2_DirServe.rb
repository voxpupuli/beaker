file_count=10  # Default files to create

# parse config file for file count
@config["CONFIG"].each_key do|cfg|
  if cfg =~ /filecount/ then							#if the config hash key is filecount
    file_count = @config["CONFIG"][cfg]		#then filecount value is num of files to create
  end
end
puts "Verifying #{file_count} files"

step "Initiate Directory Transfer on Agents"
run_agent_on agents

step "Verify Directory Existence on Agents"
on agents,"/ptest/bin/fileserve.sh /root dir #{file_count}"
