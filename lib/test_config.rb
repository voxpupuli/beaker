# Config was taken by Ruby.
module TestConfig

  def self.ssh_defaults
    {
      :config                => false,
      :paranoid              => false,
      :auth_methods          => ["publickey"],
      :keys                  => [Options.parse_args[:keyfile]],
      :port                  => 22,
      :user_known_hosts_file => "#{ENV['HOME']}/.ssh/known_hosts",
      :forward_agent         => true
    }
  end

  def self.load_file(config_file)
    config = YAML.load_file(config_file)
    # Merge some useful date into the config hash
    config['CONFIG']['ssh'] = ssh_defaults.merge(config['CONFIG']['ssh'] || {})
    config['CONFIG']['pe_ver'] = puppet_enterprise_version if puppet_enterprise_version 
    config['CONFIG']['puppet_ver'] = Options.parse_args[:puppet] unless puppet_enterprise_version
    config['CONFIG']['facter_ver'] = Options.parse_args[:facter] unless puppet_enterprise_version
    unless puppet_enterprise_version then
      config['CONFIG']['puppetpath'] = '/etc/puppet'
      config['CONFIG']['puppetbin'] = '/usr/bin/puppet'
      config['CONFIG']['puppetbindir'] = '/usr/bin'
    else   # PE speciifc
      config['CONFIG']['puppetpath'] = '/etc/puppetlabs/puppet'
      config['CONFIG']['puppetbin'] = '/usr/local/bin/puppet'
      config['CONFIG']['puppetbindir'] = '/opt/puppet/bin'
    end
    # need to load expect versions of PE binaries 
    config['VERSION'] = YAML.load_file('ci/pe/pe_version') rescue nil if puppet_enterprise_version
    config
  end

  def self.puppet_enterprise_version
    return unless Options.parse_args[:type] =~ /pe/
    return Options.parse_args[:pe_version] if Options.parse_args[:pe_version]
    version=""
    begin
      File.open("/opt/enterprise/dists/LATEST") do |file|
        while line = file.gets
          if /(\w.*)/ =~ line then
            version=$1
            Log.debug "Found: LASTEST Puppet Enterprise Version #{version}"
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
