
file_count = config['filecount'] || 10  # Default files to create

puts "Creating #{file_count} files"

# Write new class to init.pp
prep_initpp(master, "file")

step "Prep For File and Dir servering tests"
on master,"/ptest/bin/make_files.sh /etc/puppetlabs/puppet/modules/puppet_system_test/files #{file_count}"

