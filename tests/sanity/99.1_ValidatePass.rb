# Validate Positive Test

step "Validate Positive Test"

hosts.each { |host|
  puts "Host Names: #{host}"
  on host,"uname -a"
}

