# Set RVM version of Ruby?
if options[:rvm].include? 'system'
  step "Setting Ruby version to sytem default"
  on hosts, "rvm --default system" 
elsif options[:rvm].include? 'skip'
  Log.notify "Skipping set ruby version"
else 
  step "Setting Ruby version"
  on hosts, "rvm --default use #{options[:rvm]}"
end

# Add Ruby vers to host config section 
# Subscripted assignment to the Host class delegates assignment
# to the corresponding hash from Config['HOSTS']
hosts.each do |host|
  on(host, "ruby -v") do
    host[:ruby_ver] = stdout
  end
end
