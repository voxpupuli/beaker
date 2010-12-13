
file_count=10  # Default files to create

# parse config file for file count
@config["CONFIG"].each_key do|cfg|
  if cfg =~ /filecount/ then              # if the config hash key is filecount
    file_count = @config["CONFIG"][cfg]	  # then filecount value is num of files to create
  end
end

puts "Creating #{file_count} files"

initpp="/etc/puppetlabs/puppet/modules/puppet_system_test/manifests"
# Write new class to init.pp
prep_initpp(master, "file", initpp)

# Create test files/dir on Puppet Master
test_name="Prep For File and Dir servering tests"
master_run = RemoteExec.new(master)  # get remote exec obj to master
BeginTest.new(master, test_name)
result = master_run.do_remote("/ptest/bin/make_files.sh /etc/puppetlabs/puppet/modules/puppet_system_test/files #{file_count}")
result.log(test_name)
@fail_flag+=result.exit_code

