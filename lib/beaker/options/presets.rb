module Beaker
  module Options
    #A set of functions representing the environment variables and preset argument values to be incorporated
    #into the Beaker options Object.
    module Presets

      # Generates an OptionsHash of the environment variables of interest to Beaker
      # 
      # Currently supports:
      #
      #   consoleport, IS_PE, pe_dist_dir, pe_version_file, pe_version_file_win, pe_ver
      #
      # @return [OptionsHash] The supported environment variables in an OptionsHash,
      #                       empty or nil environment variables are removed from the OptionsHash
      def self.env_vars
        h = Beaker::Options::OptionsHash.new
        h.merge({
          :consoleport => ENV['consoleport'] ? ENV['consoleport'].to_i : nil,
          :type => ENV['IS_PE'] ? 'pe' : nil,
          :pe_dir => ENV['pe_dist_dir'],
          :pe_version_file => ENV['pe_version_file'],
          :pe_version_file_win => ENV['pe_version_file'],
          :pe_ver => ENV['pe_ver']
        }.delete_if {|key, value| value.nil? or value.empty? })
      end

      # Generates an OptionsHash of preset values for arguments supported by Beaker
      # 
      # @return [OptionsHash] The supported arguments in an OptionsHash
      def self.presets
        h = Beaker::Options::OptionsHash.new
        h.merge({
          :log_level => 'verbose',
          :trace_limit => 10,
          :hosts_file => 'sample.cfg',
          :options_file => nil,
          :type => 'pe',
          :provision => true,
          :preserve_hosts => 'never',
          :root_keys => false,
          :quiet => false,
          :xml => false,
          :color => true,
          :dry_run => false,
          :timeout => 300,
          :fail_mode => 'slow',
          :timesync => false,
          :repo_proxy => false,
          :add_el_extras => false,
          :consoleport => 443,
          :pe_dir => '/opt/enterprise/dists',
          :pe_version_file => 'LATEST',
          :pe_version_file_win => 'LATEST-win',
          :dot_fog => File.join(ENV['HOME'], '.fog'),
          :ec2_yaml => 'config/image_templates/ec2.yaml',
          :help => false,
          :ssh => {
            :config                => false,
            :paranoid              => false,
            :timeout               => 300,
            :auth_methods          => ["publickey"],
            :port                  => 22,
            :forward_agent         => true,
            :keys                  => ["#{ENV['HOME']}/.ssh/id_rsa"],
            :user_known_hosts_file => "#{ENV['HOME']}/.ssh/known_hosts",
          }
        })
      end

    end
  end
end
