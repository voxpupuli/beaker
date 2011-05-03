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
    # Merge some useful date into the config hash
    config['CONFIG']['ssh'] = SSH_DEFAULTS.merge(config['CONFIG']['ssh'] || {})
    config['CONFIG']['pe_ver'] = puppet_enterprise_version if puppet_enterprise_version 
    config['CONFIG']['puppet_ver'] = Options.parse_args[:puppet] unless puppet_enterprise_version
    config['CONFIG']['facter_ver'] = Options.parse_args[:facter] unless puppet_enterprise_version
    unless puppet_enterprise_version then
      config['CONFIG']['puppetpath'] = '/etc/puppet'
      config['CONFIG']['puppetbin'] = '/usr/bin/puppet'
    else   # PE paths
      config['CONFIG']['puppetpath'] = '/opt/puppet'
      config['CONFIG']['puppetbin'] = '/opt/puppet'
    end
    config
  end

  def self.puppet_enterprise_version
    return unless Options.parse_args[:type] =~ /pe/
    version=""
    begin
      File.open("tarballs/LATEST") do |file|
        while line = file.gets
          if /(\w.*)/ =~ line then
            version=$1
            Log.debug "Found: Puppet Version #{version}"
          end
        end
      end
    rescue
      version = 'unknown'
    end
    return version
  end

  # Print out test configuration
  def self.dump(config)
    # Access "platform" for each host
    require 'pp'
    pp config
    config["HOSTS"].each_key do|host|
      Log.notify "Platform for #{host} #{config["HOSTS"][host]['platform']}"
    end

    # Access "roles" for each host
    config["HOSTS"].each_key do|host|
      config["HOSTS"][host]['roles'].each do |role|
        Log.notify "Role for #{host} #{role}"
      end
    end

    # Print out Ruby versions
    config["HOSTS"].each_key do|host|
        Log.notify "Ruby version for #{host} #{config["HOSTS"][host][:ruby_ver]}"
    end

    # Access Config keys/values
    config["CONFIG"].each_key do|cfg|
        Log.notify "Config Key|Val: #{cfg} #{config["CONFIG"][cfg].inspect}"
    end
  end
end
