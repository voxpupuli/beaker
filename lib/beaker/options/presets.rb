module Beaker
  module Options
    #A class representing the environment variables and preset argument values to be incorporated
    #into the Beaker options Object.
    class Presets

      # This is a constant that describes the variables we want to collect
      # from the environment. The keys correspond to the keys in
      # `presets` (flattened) The values are an optional array of
      # environment variable names to look for. The array structure allows
      # us to define multiple environment variables for the same
      # configuration value. They are checked in the order they are arrayed
      # so that preferred and "fallback" values work as expected.
      ENVIRONMENT_SPEC = {
        :home                 => 'HOME',
        :project              => ['BEAKER_PROJECT', 'BEAKER_project'],
        :department           => ['BEAKER_DEPARTMENT', 'BEAKER_department'],
        :jenkins_build_url    => ['BEAKER_BUILD_URL', 'BUILD_URL'],
        :created_by           => ['BEAKER_CREATED_BY'],
        :consoleport          => ['BEAKER_CONSOLEPORT', 'consoleport'],
        :is_pe                => ['BEAKER_IS_PE', 'IS_PE'],
        :pe_dir               => ['BEAKER_PE_DIR', 'pe_dist_dir'],
        :pe_version_file      => ['BEAKER_PE_VERSION_FILE', 'pe_version_file'],
        :pe_ver               => ['BEAKER_PE_VER', 'pe_ver'],
        :forge_host           => ['BEAKER_FORGE_HOST', 'forge_host'],
        :package_proxy        => ['BEAKER_PACKAGE_PROXY'],
        :release_apt_repo_url => ['BEAKER_RELEASE_APT_REPO', 'RELEASE_APT_REPO'],
        :release_yum_repo_url => ['BEAKER_RELEASE_YUM_REPO', 'RELEASE_YUM_REPO'],
        :dev_builds_url       => ['BEAKER_DEV_BUILDS_URL', 'DEV_BUILDS_URL'],
        :vbguest_plugin       => ['BEAKER_VB_GUEST_PLUGIN', 'BEAKER_vb_guest_plugin'],
      }

      # Select all environment variables whose name matches provided regex
      # @return [Hash] Hash of environment variables
      def select_env_by_regex regex
        envs = Beaker::Options::OptionsHash.new
        ENV.each_pair do | k, v |
          if k.to_s =~ /#{regex}/
            envs[k] = v
          end
        end
        envs
      end

      # Takes an environment_spec and searches the processes environment variables accordingly
      #
      # @param [Hash{Symbol=>Array,String}] env_var_spec  the spec of what env vars to search for
      #
      # @return [Hash] Found environment values
      def collect_env_vars( env_var_spec )
        env_var_spec.inject({}) do |memo, key_value|
          key, value = key_value[0], key_value[1]

          set_env_var = Array(value).detect {|possible_variable| ENV[possible_variable] }
          memo[key] = ENV[set_env_var] if set_env_var

          memo
        end
      end

      # Takes a hash where the values are found environment configuration values
      # and formats them to appropriate Beaker configuration values
      #
      # @param [Hash{Symbol=>String}] found_env_vars  Environment variables to munge
      #
      # @return [Hash] Environment config values formatted appropriately
      def format_found_env_vars( found_env_vars )
        found_env_vars[:consoleport] &&= found_env_vars[:consoleport].to_i

        if found_env_vars[:is_pe]
          is_pe_val = found_env_vars[:is_pe]
          type = case is_pe_val
                 when /yes|true/ then 'pe'
                 when /no|false/ then 'foss'
                 else
                   raise "Invalid value for one of #{ENVIRONMENT_SPEC[:is_pe].join(' ,')}: #{is_pe_val}"
                 end

          found_env_vars[:type] = type
        end

        found_env_vars[:pe_version_file_win] = found_env_vars[:pe_version_file]
        found_env_vars
      end

      # Generates an OptionsHash of the environment variables of interest to Beaker
      #
      # @return [OptionsHash] The supported environment variables in an OptionsHash,
      #                       empty or nil environment variables are removed from the OptionsHash
      def calculate_env_vars
        found = Beaker::Options::OptionsHash.new
        found = found.merge(format_found_env_vars( collect_env_vars( ENVIRONMENT_SPEC )))
        found[:answers] = select_env_by_regex('\\Aq_')

        found.delete_if {|key, value| value.nil? or value.empty? }
        found
      end

      # Return an OptionsHash of environment variables used in this run of Beaker
      #
      # @return [OptionsHash] The supported environment variables in an OptionsHash,
      #                       empty or nil environment variables are removed from the OptionsHash
      def env_vars
        @env ||= calculate_env_vars
      end

      # Generates an OptionsHash of preset values for arguments supported by Beaker
      #
      # @return [OptionsHash] The supported arguments in an OptionsHash
      def presets
        h = Beaker::Options::OptionsHash.new
        h.merge({
          :project                => 'Beaker',
          :department             => 'unknown',
          :created_by             => ENV['USER'] || ENV['USERNAME'] || 'unknown',
          :jenkins_build_url      => nil,
          :validate               => true,
          :configure              => true,
          :log_level              => 'info',
          :trace_limit            => 10,
          :"master-start-curl-retries"  => 120,
          :options_file           => nil,
          :type                   => 'pe',
          :provision              => true,
          :preserve_hosts         => 'never',
          :root_keys              => false,
          :quiet                  => false,
          :project_root           => File.expand_path(File.join(File.dirname(__FILE__), "../")),
          :xml_dir                => 'junit',
          :xml_file               => 'beaker_junit.xml',
          :xml_stylesheet         => 'junit.xsl',
          :log_dir                => 'log',
          :color                  => true,
          :dry_run                => false,
          :timeout                => 300,
          :fail_mode              => 'slow',
          :accept_all_exit_codes  => false,
          :timesync               => false,
          :disable_iptables       => false,
          :repo_proxy             => false,
          :package_proxy          => false,
          :add_el_extras          => false,
          :release_apt_repo_url   => "http://apt.puppetlabs.com",
          :release_yum_repo_url   => "http://yum.puppetlabs.com",
          :dev_builds_url         => "http://builds.delivery.puppetlabs.net",
          :epel_url               => "http://mirrors.kernel.org/fedora-epel",
          :epel_arch              => "i386",
          :epel_6_pkg             => "epel-release-6-8.noarch.rpm",
          :epel_5_pkg             => "epel-release-5-4.noarch.rpm",
          :consoleport            => 443,
          :pe_dir                 => '/opt/enterprise/dists',
          :pe_version_file        => 'LATEST',
          :pe_version_file_win    => 'LATEST-win',
          :host_env               => {},
          :ssh_env_file           => '~/.ssh/environment',
          :answers                => {
                                     :q_puppet_enterpriseconsole_auth_user_email    => 'admin@example.com',
                                     :q_puppet_enterpriseconsole_auth_password      => '~!@#$%^*-/ aZ',
                                     :q_puppet_enterpriseconsole_smtp_port          => 25,
                                     :q_puppet_enterpriseconsole_smtp_use_tls       => 'n',
                                     :q_verify_packages                             => 'y',
                                     :q_puppetdb_password                           => '~!@#$%^*-/ aZ',
                                     :q_puppetmaster_enterpriseconsole_port         => 443,
                                     :q_puppet_enterpriseconsole_auth_database_name => 'console_auth',
                                     :q_puppet_enterpriseconsole_auth_database_user => 'mYu7hu3r',
                                     :q_puppet_enterpriseconsole_database_name      => 'console',
                                     :q_puppet_enterpriseconsole_database_user      => 'mYc0nS03u3r',
                                     :q_database_root_password                      => '=ZYdjiP3jCwV5eo9s1MBd',
                                     :q_database_root_user                          => 'pe-postgres',
                                     :q_database_export_dir                         => '/tmp',
                                     :q_puppetdb_database_name                      => 'pe-puppetdb',
                                     :q_puppetdb_database_user                      => 'mYpdBu3r',
                                     :q_database_port                               => 5432,
                                     :q_puppetdb_port                               => 8081,
                                     :q_classifier_database_user                    => 'DFGhjlkj',
                                     :q_database_name                               => 'pe-classifier',
                                     :q_classifier_database_password                => '~!@#$%^*-/ aZ',
                                     :q_activity_database_user                      => 'adsfglkj',
                                     :q_activity_database_name                      => 'pe-activity',
                                     :q_activity_database_password                  => '~!@#$%^*-/ aZ',
                                     :q_rbac_database_user                          => 'RbhNBklm',
                                     :q_rbac_database_name                          => 'pe-rbac',
                                     :q_rbac_database_password                      => '~!@#$%^*-/ aZ',
          },
          :dot_fog                => File.join(ENV['HOME'], '.fog'),
          :ec2_yaml               => 'config/image_templates/ec2.yaml',
          :help                   => false,
          :collect_perf_data      => false,
          :ssh                    => {
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
