unless options[:rvm].include? 'skip'
  step "Setting Ruby version"
  on hosts, "rvm --default use #{options[:rvm]}"
  step "Query Ruby Version"
  on hosts, "ruby --version"
else 
  Log.notify "Skipping set ruby version"
end
