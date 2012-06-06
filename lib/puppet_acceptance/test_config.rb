module PuppetAcceptance
  # Config was taken by Ruby.
  class TestConfig

    attr_accessor :logger
    def initialize(config_file, options)
      @options = options
      @config = load_file(config_file)
    end

    def [](key)
      @config[key]
    end

    def ssh_defaults
      {
        :config                => false,
        :paranoid              => false,
        :timeout               => 300,
        :auth_methods          => ["publickey"],
        :keys                  => [@options[:keyfile]],
        :port                  => 22,
        :user_known_hosts_file => "#{ENV['HOME']}/.ssh/known_hosts",
        :forward_agent         => true
      }
    end

    def load_file(config_file)
      config = YAML.load_file(config_file)
      # Merge some useful date into the config hash
      consoleport = ENV['consoleport'] || config['CONFIG']['consoleport'] || 443
      config['CONFIG']['consoleport']        = consoleport
      config['CONFIG']['ssh']                = ssh_defaults.merge(config['CONFIG']['ssh'] || {})
      config['CONFIG']['modules']            = @options[:modules] || []

      if is_pe?
        config['CONFIG']['pe_ver']           = puppet_enterprise_version
        config['CONFIG']['pe_ver_win']       = puppet_enterprise_version_win
      else
        config['CONFIG']['puppet_ver']       = @options[:puppet]
        config['CONFIG']['facter_ver']       = @options[:facter]
        config['CONFIG']['hiera_ver']        = @options[:hiera]
        config['CONFIG']['hiera_puppet_ver'] = @options[:hiera_puppet]
      end
      # need to load expect versions of PE binaries
      config['VERSION'] = load_dependency_versions
      config
    end

    def load_dependency_versions
      if is_pe?
        version_file = ENV['pe_dep_versions'] || 'config/versions/pe_version'
        versions = YAML.load_file version_file
        versions
      end
    end

    def is_pe?
      !! @options[:type] =~ /pe/
    end

    def load_pe_version
      dist_dir = ENV['pe_dist_dir'] || '/opt/enterprise/dists'
      version_file = ENV['pe_version_file'] || 'LATEST'
      version = ""
      begin
        File.open("#{dist_dir}/#{version_file}") do |file|
          while line = file.gets
            if /(\w.*)/ =~ line then
              version=$1.strip
              @logger.debug "Found LATEST: Puppet Enterprise Version #{version}"
            end
          end
        end
      rescue
        version = 'unknown'
      end
      return version
    end

    def puppet_enterprise_version
      @pe_ver ||= @options[:pe_version] || load_pe_version if is_pe?
    end

    def load_pe_version_win
      dist_dir = ENV['pe_dist_dir'] || '/opt/enterprise/dists'
      version_file = ENV['pe_version_file'] || 'LATEST-win'
      version = ""
      begin
        File.open("#{dist_dir}/#{version_file}") do |file|
          while line = file.gets
            if /(\w.*)/ =~ line then
              version=$1.strip
              @logger.debug "Found LATEST: Puppet Enterprise Windows Version #{version}"
            end
          end
        end
      rescue
        version = 'unknown'
      end
      return version
    end

    def puppet_enterprise_version_win
      @pe_ver_win ||= @options[:pe_version] || load_pe_version_win if is_pe?
    end

    # Print out test configuration
    def dump
      # Access "platform" for each host
      @config["HOSTS"].each_key do|host|
        @logger.notify "Platform for #{host} #{@config["HOSTS"][host]['platform']}"
      end

      # Access "roles" for each host
      @config["HOSTS"].each_key do|host|
        @config["HOSTS"][host]['roles'].each do |role|
          @logger.notify "Role for #{host} #{role}"
        end
      end

      # Print out Ruby versions
      @config["HOSTS"].each_key do|host|
          @logger.notify "Ruby version for #{host} #{@config["HOSTS"][host][:ruby_ver]}"
      end

      # Access @config keys/values
      @config["CONFIG"].each_key do|cfg|
          @logger.notify "Config Key|Val: #{cfg} #{@config["CONFIG"][cfg].inspect}"
      end
    end
  end
end
