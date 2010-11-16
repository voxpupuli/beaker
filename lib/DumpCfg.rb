# Accepts config object
# Print out test configuration
def do_dump(config)
  host=""

# Config file format
# pmaster:
#   roles:
#     - master
#     - dashboard
#   platform: RHEL
# pagent:
#   roles:
#     - agent
#   platform: RHEL


# Print hostnames (keys)
# config.each_key{|host| puts host }

# Print each hosts platform 
#config.each_key do|host|
#  puts config[host]['platform']
#end

# Print each hosts roles
#config.each_key do|host|
#  puts config[host]['roles']
#end

# Read each hosts role and report master
config.each_key do|host|
  config[host]['roles'].each do|role|
    if /master/ =~ role then
      puts "Found master #{host}"
    end
  end
end

# Read each hosts role and report agent
config.each_key do|host|
  config[host]['roles'].each do|role|
    if /agent/ =~ role then
      puts "Found agent #{host}"
    end
  end
end

# Read each hosts role and report dashboard
config.each_key do|host|
  config[host]['roles'].each do|role|
    if /dashboard/ =~ role then
     puts "Found dashboard #{host}"
    end
  end
end

end
