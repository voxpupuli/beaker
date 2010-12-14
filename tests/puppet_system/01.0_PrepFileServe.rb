
file_count=10  # Default files to create

# parse config file for file count
@config["CONFIG"].each_key do|cfg|
  if cfg =~ /filecount/ then              # if the config hash key is filecount
    file_count = @config["CONFIG"][cfg]	  # then filecount value is num of files to create
  end
end

puts "Creating #{file_count} files"

# Write new class to init.pp
prep_initpp(master, "file")

step "Prep For File and Dir servering tests"
on master,"/ptest/bin/make_files.sh /etc/puppetlabs/puppet/modules/puppet_system_test/files #{file_count}"

