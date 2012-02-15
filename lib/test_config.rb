# Config was taken by Ruby.
module TestConfig

  def self.ssh_defaults
    {
      :config                => false,
      :paranoid              => false,
      :timeout               => 300,
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
    config['CONFIG']['consoleport'] = 3000 unless config['CONFIG']['consoleport']
    config['CONFIG']['ssh'] = ssh_defaults.merge(config['CONFIG']['ssh'] || {})
    config['CONFIG']['pe_ver'] = puppet_enterprise_version if is_pe?
    config['CONFIG']['puppet_ver'] = Options.parse_args[:puppet] unless is_pe?
    config['CONFIG']['facter_ver'] = Options.parse_args[:facter] unless is_pe?
    # need to load expect versions of PE binaries
    config['VERSION'] = YAML.load_file('ci/pe/pe_version') rescue nil if is_pe?
    config
  end

  def self.is_pe?
    Options.parse_args[:type] =~ /pe/ ? true : false
  end

  def self.load_pe_version
    dist_dir = ENV['pe_dist_dir'] || '/opt/enterprise/dists'
    version_file = ENV['pe_version_file'] || 'LATEST'
    version = ""
    begin
      File.open("#{dist_dir}/#{version_file}") do |file|
        while line = file.gets
          if /(\w.*)/ =~ line then
            version=$1
            Log.debug "Found LATEST: Puppet Enterprise Version #{version}"
          end
        end
      end
    rescue
      version = 'unknown'
    end
    return version
  end

  def self.puppet_enterprise_version
    @pe_ver ||= Options.parse_args[:pe_version] || load_pe_version  if is_pe?
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
