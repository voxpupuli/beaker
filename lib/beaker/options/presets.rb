module Beaker
  module Options
    #A set of functions representing the environment variables and preset argument values to be incorporated
    #into the Beaker options Object.
    module Presets

      # Generates an OptionsHash of the environment variables of interest to Beaker
      #
      # @return [OptionsHash] The supported environment variables in an OptionsHash,
      #                       empty or nil environment variables are removed from the OptionsHash
      def self.env_vars
        h = Beaker::Options::OptionsHash.new
        consoleport = ENV['BEAKER_CONSOLEPORT'] || ENV['consoleport']
        h.merge({
          :home                => ENV['HOME'],
          :project             => ENV['BEAKER_PROJECT'] || ENV['BEAKER_project'],
          :department          => ENV['BEAKER_DEPARTMENT'] || ENV['BEAKER_department'],
          :jenkins_build_url   => ENV['BEAKER_BUILD_URL'] || ENV['BUILD_URL'],
          :consoleport         => consoleport ? consoleport.to_i : nil,
          :type                => (ENV['BEAKER_IS_PE'] || ENV['IS_PE']) ? 'pe' : nil,
          :pe_dir              => ENV['BEAKER_PE_DIR'] || ENV['pe_dist_dir'],
          :pe_version_file     => ENV['BEAKER_PE_VERSION_FILE'] || ENV['pe_version_file'],
          :pe_version_file_win => ENV['BEAKER_PE_VERSION_FILE'] || ENV['pe_version_file'],
          :pe_ver              => ENV['BEAKER_PE_VER'] || ENV['pe_ver'],
          :forge_host          => ENV['BEAKER_FORGE_HOST'] || ENV['forge_host'],
          :answers             => {
                                    :q_puppet_enterpriseconsole_auth_user_email =>
                                      ENV['q_puppet_enterpriseconsole_auth_user_email'] || 'admin@example.com',
                                    :q_puppet_enterpriseconsole_auth_password =>
                                      ENV['q_puppet_enterpriseconsole_auth_password'] || '~!@#$%^*-/ aZ',
                                    :q_puppet_enterpriseconsole_smtp_host =>
                                      ENV['q_puppet_enterpriseconsole_smtp_host'],
                                    :q_puppet_enterpriseconsole_smtp_port =>
                                      ENV['q_puppet_enterpriseconsole_smtp_port'] || 25,
                                    :q_puppet_enterpriseconsole_smtp_username =>
                                      ENV['q_puppet_enterpriseconsole_smtp_username'],
                                    :q_puppet_enterpriseconsole_smtp_password =>
                                      ENV['q_puppet_enterpriseconsole_smtp_password'],
                                    :q_puppet_enterpriseconsole_smtp_use_tls =>
                                      ENV['q_puppet_enterpriseconsole_smtp_use_tls'] || 'n',
                                    :q_verify_packages =>
                                      ENV['q_verify_packages'] || 'y',
                                    :q_puppetdb_password =>
                                      ENV['q_puppetdb_password'] || '~!@#$%^*-/ aZ',
                                  }
        }.delete_if {|key, value| value.nil? or value.empty? })
      end

      # Generates an OptionsHash of preset values for arguments supported by Beaker
      #
      # @return [OptionsHash] The supported arguments in an OptionsHash
      def self.presets
        h = Beaker::Options::OptionsHash.new
        h.merge({
          :project             => 'Beaker',
          :department          => ENV['USER'] || ENV['USERNAME'] || 'unknown',
          :validate            => true,
          :jenkins_build_url   => nil,
          :forge_host          => 'vulcan-acceptance.delivery.puppetlabs.net',
          :log_level           => 'verbose',
          :trace_limit         => 10,
          :hosts_file          => 'sample.cfg',
          :options_file        => nil,
          :type                => 'pe',
          :provision           => true,
          :preserve_hosts      => 'never',
          :root_keys           => false,
          :quiet               => false,
          :xml                 => false,
          :color               => true,
          :dry_run             => false,
          :timeout             => 300,
          :fail_mode           => 'slow',
          :timesync            => false,
          :repo_proxy          => false,
          :add_el_extras       => false,
          :add_master_entry    => false,
          :consoleport         => 443,
          :pe_dir              => '/opt/enterprise/dists',
          :pe_version_file     => 'LATEST',
          :pe_version_file_win => 'LATEST-win',
          :dot_fog             => File.join(ENV['HOME'], '.fog'),
          :ec2_yaml            => 'config/image_templates/ec2.yaml',
          :help                => false,
          :ssh                 => {
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
