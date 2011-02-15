# Config was taken by Ruby.
module TestConfig
  SSH_DEFAULTS = {
    :config                => false,
    :paranoid              => false,
    :auth_methods          => ["publickey"],
    :keys                  => ["#{ENV['HOME']}/.ssh/id_rsa"],
    :port                  => 22,
    :user_known_hosts_file => "#{ENV['HOME']}/.ssh/known_hosts"
  }

  def self.load_file(config_file)
    config = YAML.load_file(config_file)

    # Merge our default SSH options into the configuration.
    config['CONFIG']['ssh'] = SSH_DEFAULTS.merge(config['CONFIG']['ssh'] || {})
    config["CONFIG"]["puppetver"] = puppet_version
    config
  end

  def self.puppet_version
    version=""

    unless File.file? "#{$work_dir}/tarballs/LATEST"
      puts " Can not find: #{$work_dir}/tarballs/LATEST"
    end

    begin
      File.open("#{$work_dir}/tarballs/LATEST") do |file|
        while line = file.gets
          if /(\w.*)/ =~ line then
            version=$1
            puts "Found: Puppet Version #{version}"
          end
        end
      end
    rescue
      version = 'unknown'
    end
    return version
  end

  # Accepts conf
  # Print out test configuration
  def self.dump(config)
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
        puts "Config Key|Val: #{cfg} #{config["CONFIG"][cfg].inspect}"
    end
  end
end
