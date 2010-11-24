# Accepts conf
# Print out test configuration
def do_dump(config)

# Config file format
# HOSTS:
#   pmaster:
#     roles:
#       - master
#       - dashboard
#     platform: RHEL
#   pagent:
#     roles:
#       - agent
#     platform: RHEL
# CONFIG:
#   rubyver: ruby18
#   facterver: fact11
#   puppetbinpath: /opt/puppet/bin

# Print the main categories
#config.each_key do|category|
#  puts "Main Category: #{category}"
#end

# Print sub keys to main categories
#config.each_key do|category|
#  config["#{category}"].each_key do|subkey|
#    puts "1st Level Subkeys: #{subkey}"
#  end
#end

# Print out hosts 
#config["HOSTS"].each_key do|host|
#    puts "Host Names: #{host}"
#end

# Print out hosts and all sub info
#config["HOSTS"].each_key do|host|
#    puts "Host Names: #{host} #{config["HOSTS"][host]}"
#
#end

# Access "platform" for each host
config["HOSTS"].each_key do|host|
  puts "Platform for #{host} #{config["HOSTS"][host]['platform']}"
end

# Access "roles" for each host
config["HOSTS"].each_key do|host|
  config["HOSTS"][host]['roles'].each do |role|
    puts "Role for #{host} #{role}"
  end
end

# Access Config keys/values
config["CONFIG"].each_key do|cfg|
    puts "Config Key|Val: #{cfg} #{config["CONFIG"][cfg]}"
end

end
