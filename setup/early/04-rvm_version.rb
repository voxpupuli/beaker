# Set RVM version of Ruby?
if options[:rvm].include? 'system'
  step "Setting Ruby version to sytem default"
  on hosts, "rvm --default system" 
elsif options[:rvm].include? 'skip'
  logger.notify "Skipping set ruby version"
  skip_test "Skipping set ruby version"
else 
  step "Setting Ruby version"
  on hosts, "rvm --default use #{options[:rvm]}"
end
