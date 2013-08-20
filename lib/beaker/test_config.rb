require 'open-uri'
require 'yaml'

module Beaker
  # Config was taken by Ruby.
  class TestConfig

    attr_accessor :logger
    def initialize(config_file, options)
      @options = options
      @logger = options[:logger]
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
      if config_file.is_a? Hash
        config = config_file
      else
        config = YAML.load_file(config_file)

        # Make sure the roles array is present for all hosts
        config['HOSTS'].each_key do |host|
          config['HOSTS'][host]['roles'] ||= []
        end
      end

      # Merge some useful date into the config hash
      config['CONFIG'] ||= {}
      consoleport = ENV['consoleport'] || config['CONFIG']['consoleport'] || 443
      config['CONFIG']['consoleport']        = consoleport.to_i
      config['CONFIG']['ssh']                = ssh_defaults.merge(config['CONFIG']['ssh'] || {})
      config['CONFIG']['modules']            = @options[:modules] || []

      if is_pe?
        config['CONFIG']['pe_dir']           = puppet_enterprise_dir
        config['CONFIG']['pe_ver']           = puppet_enterprise_version
        config['CONFIG']['pe_ver_win']       = puppet_enterprise_version_win
      else
        config['CONFIG']['puppet_ver']       = @options[:puppet]
        config['CONFIG']['facter_ver']       = @options[:facter]
        config['CONFIG']['hiera_ver']        = @options[:hiera]
        config['CONFIG']['hiera_puppet_ver'] = @options[:hiera_puppet]
      end
      # need to load expect versions of PE binaries
      config
    end

    def is_pe?
      @is_pe ||= @options[:type] =~ /pe/ ? true : false
      unless ENV['IS_PE'].nil?
        @is_pe ||= ENV['IS_PE'] == 'true'
      end
      @is_pe
    end

    def puppet_enterprise_dir
      @pe_dir ||= ENV['pe_dist_dir'] || '/opt/enterprise/dists'
    end

    def load_pe_version
      dist_dir = puppet_enterprise_dir
      version_file = ENV['pe_version_file'] || 'LATEST'
      version = ""
      begin
        open("#{dist_dir}/#{version_file}") do |file|
          while line = file.gets
            if /(\w.*)/ =~ line then
              version = $1.strip
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
      @pe_ver ||= load_pe_version if is_pe?
    end

    def load_pe_version_win
      dist_dir = puppet_enterprise_dir
      version_file = ENV['pe_version_file'] || 'LATEST-win'
      version = ""
      begin
        open("#{dist_dir}/#{version_file}") do |file|
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
      @pe_ver_win ||= load_pe_version_win if is_pe?
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
